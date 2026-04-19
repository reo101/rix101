(import sys os re)

(defn log [msg]
  (.write sys.stdout f"PATCHER: {msg}\n")
  (.flush sys.stdout))

(defn get-tag-for-keyword [kw]
  (setv length (len kw))
  (cond
    (= length 3) "tag_todo"
    (= length 4) "tag_todo"
    (= length 5) "tag_fixme"
    (= length 7) "tag_warning"
    True (do
           (log f"WARNING: Keyword '{kw}' has unsupported length {length}. Skipping.")
           None)))

(defn patch-fea [file-path extra-escape pill-keywords disable-alt-pill]
  (log f"Patching FEA: {file-path}")
  (setv content "")
  (with [f (open file-path "r" :encoding "utf-8")]
    (setv content (f.read)))

  ;; 1. Patch escape lookup
  (if extra-escape
    (do
      (setv escape-pattern (re.compile r"(@Escape\s*=\s*\[)([^\]]*)(\];)" re.DOTALL))
      (defn add-escape [match]
        (setv head (match.group 1))
        (setv body (.rstrip (match.group 2)))
        (setv tail (match.group 3))
        (setv added (.join " " extra-escape))
        (+ head body " " added " " tail))
      (setv content (escape-pattern.sub add-escape content)))
    None)

  ;; 2. Patch pill ligatures
  (if disable-alt-pill
    (do
      (setv content (re.sub r"lookup tag_todo_alt \{.*?\} tag_todo_alt;" "" content :flags re.DOTALL))
      (setv content (re.sub r"lookup tag_fixme_alt \{.*?\} tag_fixme_alt;" "" content :flags re.DOTALL))
      (setv content (re.sub r"lookup tag_todo_alt;" "" content))
      (setv content (re.sub r"lookup tag_fixme_alt;" "" content)))
    None)

  ;; 3. Add new pill keywords
  (setv new-lookups [])
  (setv calt-lookups [])
  (setv ss03-lookups [])

  (if pill-keywords
    (for [kw pill-keywords]
      (setv liga (get-tag-for-keyword kw))
      (if liga
        (do
          (setv kw-lower (.lower kw))
          (setv lookup-name f"tag_custom_{kw_lower}")
          (if (not (in f"lookup {lookup-name} {{" content))
            (do
              (setv l f"  lookup {lookup-name} {{\n")
              (setv seq-len (+ (len kw) 2))
              (setv target-width (cond (= liga "tag_todo") 6 (= liga "tag_fixme") 7 (= liga "tag_warning") 9 True 6))
              (setv padding "")
              (if (> target-width seq-len)
                (setv padding (* "SPC " (- target-width seq-len)))
                None)

              (setv spaces-main (* "SPC " (- target-width 1)))
              (setv l (+ l f"    sub {spaces-main}bracketright' {padding} by {liga}.liga;\n"))
              (for [i (range (len kw))]
                (setv char (get kw (- (+ i 1))))
                (setv spaces-loop (* "SPC " (- (len kw) i)))
                (if (= i 0)
                  (setv l (+ l f"    sub {spaces-loop} {char}' bracketright {padding} by SPC;\n"))
                  (do
                    (setv slice-start (- i))
                    (setv kw-suffix (get kw (slice slice-start None)))
                    (setv chars-after (.join " " kw-suffix))
                    (setv l (+ l f"    sub {spaces-loop} {char}' {chars-after} bracketright {padding} by SPC;\n")))))

              (setv chars-all (.join " " kw))
              (setv l (+ l f"    sub bracketleft' {chars-all} bracketright {padding} by SPC;\n"))
              (setv l (+ l f"  }} {lookup-name};\n"))
              (new-lookups.append l)
              (calt-lookups.append lookup-name)

              ;; SS03 lookup (case insensitive)
              (setv ss03-lookup-name f"{lookup-name}_ss03")
              (setv l f"  lookup {ss03-lookup-name} {{\n")
              (setv l (+ l f"    sub {spaces-main}bracketright' {padding} by {liga}.liga;\n"))
              (setv kw-classes (lfor c kw f"@{c}"))
              (for [i (range (len kw))]
                (setv char-class (get kw-classes (- (+ i 1))))
                (setv spaces-loop (* "SPC " (- (len kw) i)))
                (if (= i 0)
                  (setv l (+ l f"    sub {spaces-loop} {char-class}' bracketright by SPC;\n"))
                  (do
                    (setv slice-start (- i))
                    (setv class-suffix (get kw-classes (slice slice-start None)))
                    (setv classes-after (.join " " class-suffix))
                    (setv l (+ l f"    sub {spaces-loop} {char-class}' {classes-after} bracketright by SPC;\n")))))
              (setv classes-all (.join " " kw-classes))
              (setv l (+ l f"    sub bracketleft' {classes-all} bracketright by SPC;\n"))
              (setv l (+ l f"  }} {ss03-lookup-name};\n"))
              (new-lookups.append l)
              (ss03-lookups.append ss03-lookup-name))
            None))
        None))
    None)

  (if new-lookups
    (do
      (if (not (in "feature calt {" content))
        (setv content (+ content "\nfeature calt {\n} calt;\n"))
        None)
      (if (not (in "feature ss03 {" content))
        (setv content (+ content "\nfeature ss03 {\n} ss03;\n"))
        None)
      (setv joined-lookups (.join "\n" new-lookups))
      (setv content (.replace content "feature calt {" (+ joined-lookups "\nfeature calt {")))
      (for [l calt-lookups]
        (setv content (.replace content "feature calt {" f"feature calt {{\n    lookup {l};")))
      (for [l ss03-lookups]
        (setv content (.replace content "feature ss03 {" f"feature ss03 {{\n    lookup {l};"))))
    None)

  (with [f (open file-path "w" :encoding "utf-8")]
    (f.write content)))

(defn patch-build-py [file-path]
  (log f"Patching {file-path}...")
  (with [f (open file-path "r" :encoding "utf-8")]
    (setv content (f.read)))

  ;; 1. Add --style argument
  (if (not (in "--style" content))
    (do
      (log "Adding --style argument to build.py")
      (setv content (.replace content
                     "parser.add_argument(\"--least-styles\", action=\"store_true\", help=\"least styles\")"
                     "parser.add_argument(\"--least-styles\", action=\"store_true\", help=\"least styles\")\n    parser.add_argument(\"--style\", help=\"build specific style\")")))
    None)


  ;; 2. Patch target_styles assignment using a line-based search
  (setv lines (.splitlines content))
  (setv new-lines [])
  (setv patched False)
  (setv target-regex (re.compile r"target_styles\s*=\s*\("))

  (for [line lines]
    (if (and (not patched) (target-regex.search line))
      (do
        (log f"FOUND target_styles on line: {line}")
        (setv indent (get (.split line "target_styles") 0))
        (new-lines.append f"{indent}if getattr(parsed_args, 'style', None):")
        (new-lines.append f"{indent}    target_styles = [parsed_args.style]")
        (new-lines.append f"{indent}else:")
        (new-lines.append f"    {line}")
        (setv patched True))
      (new-lines.append line)))
  (if patched
    (log "Successfully patched target_styles")
    (log "CRITICAL: target_styles assignment NOT found in build.py!"))
  (with [f (open file-path "w" :encoding "utf-8" :newline "\n")]
    (f.write (.join "\n" new-lines))))


(if (= __name__ "__main__")
  (do
    (log "Patch script started")
    (if (< (len sys.argv) 4)
      (do
        (log "Insufficient arguments")
        (sys.exit 1))
      (do
        (setv extra-escape (if (get sys.argv 1) (.split (get sys.argv 1) ",") []))
        (setv pill-keywords (if (get sys.argv 2) (.split (get sys.argv 2) ",") []))
        (setv disable-alt-pill (= (get sys.argv 3) "1"))
        (setv fea-files ["source/features/regular.fea" "source/features/italic.fea" "source/features/regular_cn.fea" "source/features/italic_cn.fea"])
        (for [f fea-files]
          (if (os.path.exists f) (patch-fea f extra-escape pill-keywords disable-alt-pill) None))
        (if (os.path.exists "build.py") (patch-build-py "build.py") None)
        (log "Patch script finished"))))
  None)
