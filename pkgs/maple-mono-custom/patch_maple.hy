(import sys json importlib dataclasses io os shutil)

;; The script lives in the source root, but Hy does not put the CWD on sys.path.
(.insert sys.path 0 (os.getcwd))

;; The v8 pipeline spawns workers with sys.executable. Under Hy that points at
;; the Hy launcher, which does not accept Python's -s flag.
(setv sys.executable (or (shutil.which "python") (os.path.join sys.prefix "bin" "python")))

(setv cfg (json.loads (get sys.argv 1)))
(setv style (get cfg "style"))
(setv least-styles (get cfg "leastStyles"))
(setv extra-escape (get cfg "extraEscape"))
(setv pill-keywords (get cfg "pillKeywords"))
(setv disable-alt-pill (get cfg "disableAltPill"))
(setv pill-style (get cfg "pillStyle"))
(setv features (get cfg "features"))
(setv hinted (get cfg "hinted"))
(setv ligature (get cfg "ligature"))
(setv nerd-font (get cfg "nerdFont"))
(setv cjk (get cfg "cjk"))

(setv pipeline (importlib.import_module "scripts.pipeline"))
(setv orch (importlib.import_module "scripts.pipeline.orchestrator"))
(setv apply-mod (importlib.import_module "scripts.feature.apply"))
(setv ft-mod (importlib.import_module "scripts.font_ops.fonttools"))
(setv tag-mod (importlib.import_module "scripts.feature.calt.tag"))
(setv ast-mod (importlib.import_module "scripts.feature.ast"))
(setv fea-parser-mod (importlib.import_module "fontTools.feaLib.parser"))
(setv fea-ast (importlib.import_module "fontTools.feaLib.ast"))
(setv futures-mod (importlib.import_module "concurrent.futures"))

(setv Parser (getattr fea-parser-mod "Parser"))
(setv GlyphClassDefinition (getattr fea-ast "GlyphClassDefinition"))
(setv LookupBlock (getattr fea-ast "LookupBlock"))
(setv LookupReferenceStatement (getattr fea-ast "LookupReferenceStatement"))
(setv built-in-tags (getattr tag-mod "built_in_tag_text"))
(setv PreparedFeatureSource (getattr apply-mod "PreparedFeatureSource"))

(setv pill-caps
  (cond
    (= pill-style "circle") ["circle_start.bg" "circle_end.bg"]
    (= pill-style "sharp") ["sharp_start.bg" "sharp_end.bg"]
    True ["block_start.bg" "block_end.bg"]))

;; v8 exposes --least-styles but not a single-style option. Force the plan and
;; the pipeline's copy of target_styles after the config resolver has run.
(when style
  (setv Pipeline (getattr orch "MapleBuildPipeline"))
  (setv orig-init (getattr Pipeline "__init__"))
  (defn init [self #* args #** kwargs]
    (orig-init self #* args #** kwargs)
    (setv self.target-styles [style])
    (setv self.plan (dataclasses.replace self.plan :target-styles [style])))
  (setattr Pipeline "__init__" init))

;; Keep the build in one process. The v8 forkserver cannot import a .hy main,
;; and thread workers inherit the monkeypatches without pickling.
(setv ThreadPoolExecutor (getattr futures-mod "ThreadPoolExecutor"))
(defn thread-executor [max-workers #** kwargs]
  (ThreadPoolExecutor max-workers))
(setattr orch "create_process_executor" thread-executor)

;; CJK saves recompile the whole glyf table. The source masters already carry
;; valid bounding boxes, so skip the recalculation.
(setv TTFont (getattr ft-mod "TTFont"))
(setv orig-save (getattr TTFont "save"))
(defn fast-save [self file [reorder-tables True]]
  (setv self.recalcBBoxes False)
  (orig-save self file :reorderTables None))
(setattr TTFont "save" fast-save)

(defn patch-escape-statements [statements extra]
  (for [stmt statements]
    (when (and (isinstance stmt GlyphClassDefinition) (= stmt.name "Escape"))
      (for [g extra]
        (when (not (in g (getattr stmt.glyphs "glyphs")))
          (.append stmt.glyphs g))))
    (when (hasattr stmt "statements")
      (patch-escape-statements stmt.statements extra))))

(defn patch-escape [feature-file extra]
  (patch-escape-statements feature-file.statements extra))

(setv alt-names #{"tag_todo_alt" "tag_fixme_alt"})

(defn drop-alt [statements]
  (setv kept [])
  (for [stmt statements]
    (setv drop False)
    (when (and (isinstance stmt LookupBlock) (in stmt.name alt-names))
      (setv drop True))
    (when (and (isinstance stmt LookupReferenceStatement) (in stmt.lookup.name alt-names))
      (setv drop True))
    (when (not drop)
      (when (hasattr stmt "statements")
        (setv stmt.statements (drop-alt stmt.statements)))
      (.append kept stmt)))
  kept)

(defn custom-tag-text [keywords glyph-names]
  (setv lookups [])
  (setv refs [])
  (setv seen #{})
  (for [kw keywords]
    (setv k (.lower kw))
    (setv chars (list kw))
    (when (and (not (in k built-in-tags))
               (not (in k seen))
               chars
               (all (lfor c chars (.isalpha c))))
      (setv needed (list pill-caps))
      (for [c chars] (.append needed f"{(.upper c)}.bg"))
      (when (all (lfor g needed (in g glyph-names)))
        (.add seen k)
        (setv src [])
        (.append src (ast-mod.gly "["))
        (for [c chars] (.append src f"@{(.upper c)}"))
        (.append src (ast-mod.gly "]"))
        (setv tgt [(get pill-caps 0)])
        (for [c chars] (.append tgt f"{(.upper c)}.bg"))
        (.append tgt (get pill-caps 1))
        (setv subs [])
        (for [i (range (len src) 0 -1)]
          (setv before (get tgt (slice 0 (- i 1))))
          (setv after (if (< i (len src)) (get src (slice i None)) None))
          (.append subs (ast-mod.subst before (get src (- i 1)) after (get tgt (- i 1)))))
        (setv lookup (ast-mod.Lookup :name f"custom_tag_{k}" :desc f"[{kw}]" :content subs))
        (.append lookups (ast-mod.create [lookup]))
        (.append refs f"    lookup custom_tag_{k};"))))
  (if lookups
    (+ "\n" (.join "\n" lookups) "\nfeature calt {\n" (.join "\n" refs) "\n} calt;\n")
    ""))

(defn patch-prepared [prepared kwargs]
  (setv glyph-names (get kwargs "glyph_names"))
  (setv text prepared.source)
  (when (or extra-escape disable-alt-pill)
    (setv feature-file (.parse (Parser (io.StringIO text) :glyphNames glyph-names)))
    (when extra-escape
      (patch-escape feature-file extra-escape))
    (when disable-alt-pill
      (setv feature-file.statements (drop-alt feature-file.statements)))
    (setv text (.asFea feature-file)))
  (PreparedFeatureSource (+ text (custom-tag-text pill-keywords glyph-names)) prepared.substitutions))

(setv orig-prepare (getattr apply-mod "prepare_feature_source"))
(defn prepare [config #* args #** kwargs]
  (setv prepared (orig-prepare config #* args #** kwargs))
  (patch-prepared prepared kwargs))
(setattr apply-mod "prepare_feature_source" prepare)

(setv build-args ["--format" "ttf" "--apply-fea-file"])
(when (and (not style) least-styles)
  (.append build-args "--least-styles"))
(when features
  (.extend build-args ["--feat" (.join "," features)]))
(.extend build-args (if hinted ["--hinted"] ["--no-hinted"]))
(.extend build-args (if ligature ["--liga"] ["--no-liga"]))
(.extend build-args (if nerd-font ["--nf"] ["--no-nf"]))
(when cjk
  (.extend build-args ["--cjk" "cn"]))

(print "maple-mono-custom build args:" build-args)
(pipeline.main build-args)
