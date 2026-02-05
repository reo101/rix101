#!/usr/bin/env bb

(ns wayland.portty-helper
  (:require [babashka.fs :as fs]
            [babashka.process :as process]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def session-id-pattern
  #"[0-9a-f]+-[0-9a-f]+")

(defn command-output [cmd]
  (let [{:keys [exit out]} @(process/process {:cmd cmd :out :string :err :string :continue true})]
    (when (zero? exit)
      (some-> out str/trim not-empty))))

(def current-uid
  (delay
    (or
      (System/getenv "UID")
      (command-output ["id" "-u"])
      (throw (ex-info "Failed to determine current uid" {})))))

(def portty-base-dir
  (delay
    (fs/path "/tmp/portty" @current-uid)))

(def active-session-file
  (delay
    (let [state-home (or (System/getenv "XDG_STATE_HOME")
                         (str (fs/path (or (System/getenv "HOME")
                                           (System/getProperty "user.home"))
                                       ".local"
                                       "state")))]
      (fs/path state-home "portty" "active-session"))))

(defn read-trimmed-file [path]
  (when (fs/exists? path)
    (some-> path str slurp str/trim not-empty)))

(defn read-json-file [path]
  (when (fs/exists? path)
    (try
      (json/parse-string (slurp (str path)) true)
      (catch Exception _
        nil))))

(defn write-trimmed-file! [path value]
  (fs/create-dirs (fs/parent path))
  (spit (str path) (str value "\n")))

(defn session-dir [session-id]
  (fs/path @portty-base-dir session-id))

(defn session-exists? [session-id]
  (and (some? session-id)
       (fs/directory? (session-dir session-id))))

(defn session-sort-key [session-id]
  (let [[timestamp sequence] (str/split session-id #"-")]
    [(java.math.BigInteger. timestamp 16)
     (java.math.BigInteger. sequence 16)]))

(defn active-sessions []
  (if (fs/directory? @portty-base-dir)
    (->> (fs/list-dir @portty-base-dir)
         (filter fs/directory?)
         (map fs/file-name)
         (filter #(re-matches session-id-pattern %))
         (sort-by session-sort-key))
    []))

(defn first-active-session []
  (first (active-sessions)))

(defn latest-active-session []
  (last (active-sessions)))

(defn resolve-session []
  (or
    (let [session-id (System/getenv "PORTTY_SESSION")]
      (when (session-exists? session-id)
        session-id))
    (let [session-id (read-trimmed-file @active-session-file)]
      (when (session-exists? session-id)
        session-id))
    (first-active-session)))

(defn emit! [stream text]
  (when (seq text)
    (binding [*out* stream]
      (print text)
      (flush))))

(defn markup-escape [value]
  (-> (str value)
      (str/replace "&" "&amp;")
      (str/replace "<" "&lt;")
      (str/replace ">" "&gt;")))

(defn detail-line [label value]
  (when-let [value (some-> value str str/trim not-empty)]
    (str "<b>" (markup-escape label) ":</b> " (markup-escape value))))

(defn summarize-values [values]
  (let [values (vec (keep #(some-> % str str/trim not-empty) values))
        shown (take 4 values)
        hidden (- (count values) (count shown))]
    (when (seq shown)
      (str (str/join ", " shown)
           (when (pos? hidden)
             (str " (+" hidden " more)"))))))

(defn run-command
  [cmd & {:keys [stdin extra-env inherit?]}]
  (let [opts (cond-> {:cmd cmd
                      :continue true}
               inherit? (assoc :inherit true)
               (not inherit?) (assoc :out :string :err :string)
               (some? stdin) (assoc :in stdin)
               extra-env (assoc :extra-env extra-env))
        {:keys [exit out err]} @(process/process opts)]
    (emit! *out* out)
    (emit! *err* err)
    exit))

(defn start-command
  [cmd & {:keys [extra-env inherit?]}]
  (process/process
    (cond-> {:cmd cmd
             :continue true}
      inherit? (assoc :inherit true)
      (not inherit?) (assoc :out :string :err :string)
      extra-env (assoc :extra-env extra-env))))

(defn exec-command! [cmd & {:keys [extra-env]}]
  (process/exec
    (cond-> {:cmd cmd}
      extra-env (assoc :extra-env extra-env))))

(defn fail! [message]
  (emit! *err* (str message "\n"))
  1)

(defn selected-wayland-display []
  (let [existing (System/getenv "WAYLAND_DISPLAY")
        runtime-dir (System/getenv "XDG_RUNTIME_DIR")]
    (cond
      (seq existing) existing
      (and runtime-dir (fs/exists? (fs/path runtime-dir "wayland-1"))) "wayland-1"
      (and runtime-dir (fs/exists? (fs/path runtime-dir "wayland-0"))) "wayland-0"
      :else nil)))

(defn with-wayland-display [env]
  (if-let [wayland-display (selected-wayland-display)]
    (assoc env "WAYLAND_DISPLAY" wayland-display)
    env))

(defn session-id-from-dir-env []
  (some-> (System/getenv "PORTTY_DIR")
          fs/file-name
          not-empty))

(defn session-portal-info [session-id]
  (or
    (let [portal (System/getenv "PORTTY_PORTAL")
          operation (System/getenv "PORTTY_OPERATION")]
      (when (and (seq portal) (seq operation))
        {:portal portal
         :operation operation}))
    (when-let [[portal operation] (some-> (fs/path (session-dir session-id) "portal")
                                          read-trimmed-file
                                          str/split-lines
                                          seq)]
      {:portal portal
       :operation operation})))

(defn session-options [session-id]
  (read-json-file (fs/path (session-dir session-id) "options.json")))

(defn wait-for-session []
  (if-let [known-session (or (System/getenv "PORTTY_SESSION")
                             (session-id-from-dir-env))]
    (loop [attempts 30]
      (cond
        (session-exists? known-session) known-session
        (zero? attempts) nil
        :else (do
                (Thread/sleep 100)
                (recur (dec attempts)))))
    (loop [attempts 30]
      (or
        (latest-active-session)
        (when (pos? attempts)
          (Thread/sleep 100)
          (recur (dec attempts)))))))

(defn clear-active-session! [session-id]
  (when (= (read-trimmed-file @active-session-file) session-id)
    (fs/delete @active-session-file)))

(defn submit-session! [session-id]
  (let [exit (run-command ["portty" "--session" session-id "submit"] :inherit? true)]
    (when (zero? exit)
      (clear-active-session! session-id))
    exit))

(defn wait-for-session-cleanup! [session-id]
  (loop [attempts 20]
    (when (and (pos? attempts)
               (fs/exists? (session-dir session-id)))
      (Thread/sleep 100)
      (recur (dec attempts)))))

(defn file-chooser-mode-label [mode]
  (cond
    (string? mode)
    (case mode
      "Save" "Save file"
      "SaveMultiple" "Save multiple files"
      mode)

    (map? mode)
    (if-let [pick (or (:Pick mode) (get mode "Pick"))]
      (let [multiple? (true? (or (:multiple pick) (get pick "multiple")))
            directory? (true? (or (:directory pick) (get pick "directory")))]
        (cond
          (and multiple? directory?) "Pick directories"
          directory? "Pick directory"
          multiple? "Pick files"
          :else "Pick file"))
      (some-> mode keys first name))

    :else nil))

(defn filter-pattern-label [pattern]
  (cond
    (string? pattern) pattern
    (map? pattern) (or (:Glob pattern)
                       (get pattern "Glob")
                       (:MimeType pattern)
                       (get pattern "MimeType"))
    :else (some-> pattern str)))

(defn filter-label [filter]
  (let [name (or (:name filter) (get filter "name"))
        patterns (->> (or (:patterns filter) (get filter "patterns"))
                      (keep filter-pattern-label)
                      summarize-values)]
    (summarize-values (remove nil? [name patterns]))))

(defn file-chooser-popup-sections [operation options]
  (let [mode (file-chooser-mode-label (:mode options))
        folder (:current_folder options)
        candidates (:candidates options)
        filters (->> (:filters options)
                     (keep filter-label)
                     summarize-values)
        candidate-label (case operation
                          "save-file" "Suggested name"
                          "save-files" "Suggested files"
                          "open-file" "Selection"
                          (str "Operation '" operation "'"))]
    [(or (detail-line "Request" mode)
         (detail-line "Request" operation))
     (detail-line "Folder" folder)
     (detail-line candidate-label (summarize-values candidates))
     (detail-line "Filters" filters)]))

(defn screenshot-mode-label [mode]
  (cond
    (string? mode)
    (case mode
      "PickColor" "Pick color"
      mode)

    (map? mode)
    (cond
      (contains? mode :PickColor) "Pick color"
      (contains? mode "PickColor") "Pick color"
      (contains? mode :Screenshot)
      (let [config (or (:Screenshot mode) (get mode "Screenshot"))]
        (if (true? (or (:interactive config) (get config "interactive")))
          "Interactive screenshot"
          "Screenshot"))
      (contains? mode "Screenshot")
      (let [config (get mode "Screenshot")]
        (if (true? (or (:interactive config) (get config "interactive")))
          "Interactive screenshot"
          "Screenshot")))

    :else nil))

(defn screenshot-popup-sections [options]
  [(detail-line "Request" (screenshot-mode-label (:mode options)))
   (detail-line "App" (:app_id options))])

(defn popup-message [session-id]
  (let [{:keys [portal operation]} (session-portal-info session-id)
        options (session-options session-id)
        title (or (:title options)
                  (case portal
                    "file-chooser" "Portty File Picker"
                    "screenshot" "Portty Portal"
                    "Portty Portal"))
        details (case portal
                  "file-chooser" (file-chooser-popup-sections operation options)
                  "screenshot" (screenshot-popup-sections options)
                  [(detail-line "Portal" portal)
                   (detail-line "Operation" operation)])
        instructions (remove nil?
                             [(detail-line "From any terminal" "Use sel to add entries")
                              (detail-line "Finish" "Run submit or press OK")])]
    (str/join
      "\n\n"
      (remove nil?
              [(str "<b>" (markup-escape title) "</b>")
               (some->> details (remove nil?) seq (str/join "\n"))
               (some->> instructions seq (str/join "\n"))]))))

(defn wait-for-command-or-session-finish [proc session-id]
  (loop []
    (cond
      (not (process/alive? proc))
      {:reason :command-exited
       :result @proc}

      (not (session-exists? session-id))
      (do
        (process/destroy proc)
        {:reason :session-finished
         :result @proc})

      :else
      (do
        (Thread/sleep 100)
        (recur)))))

(defn handle-resolve-session []
  (if-let [session-id (resolve-session)]
    (do
      (println session-id)
      0)
    1))

(defn handle-sel [items]
  (if-let [session-id (resolve-session)]
    (if (seq items)
      (exec-command! (into ["portty" "--session" session-id "edit"] items))
      (exec-command! ["portty" "--session" session-id "edit" "--stdin"]))
    (fail! "portty-sel: no active portty session")))

(defn handle-submit []
  (if-let [session-id (resolve-session)]
    (submit-session! session-id)
    (fail! "portty-submit: no active portty session")))

(defn handle-session-holder []
  (if-let [session-id (wait-for-session)]
    (do
      (write-trimmed-file! @active-session-file session-id)
      (try
        (let [{:keys [reason result]}
              (wait-for-command-or-session-finish
                (start-command
                  ["zenity"
                   "--info"
                   "--title=Portty File Picker"
                   "--width=520"
                   (str "--text=" (popup-message session-id))]
                  :inherit? true
                  :extra-env (with-wayland-display
                               {"DISPLAY" ""
                                "GDK_BACKEND" "wayland"}))
                session-id)]
          (case reason
            :session-finished 0
            :command-exited
            (let [zenity-exit (:exit result)]
              (if (zero? zenity-exit)
                (do
                  (submit-session! session-id)
                  (wait-for-session-cleanup! session-id)
                  0)
                (fail! (str "portty-session-holder: popup exited with status "
                            zenity-exit
                            "; skipping auto-submit"))))))
        (finally
          (clear-active-session! session-id))))
    (fail! "portty-session-holder: no active session")))

(defn handle-porttyd-wrapper []
  (exec-command!
    ["porttyd"]
    :extra-env (with-wayland-display {})))

(defn usage []
  (str/join
    "\n"
    ["Usage:"
     "  portty-helper resolve-session"
     "  portty-helper sel [PATH ...]"
     "  portty-helper submit"
     "  portty-helper session-holder"
     "  portty-helper porttyd-wrapper"]))

(defn resolve-command [[command & args :as argv]]
  (if-let [intent (some-> (System/getenv "PORTTY_HELPER_INTENT")
                          str/trim
                          not-empty)]
    [intent argv]
    [command args]))

(defn -main [argv]
  (let [[command args] (resolve-command argv)]
    (case command
      "resolve-session" (handle-resolve-session)
      "sel" (handle-sel args)
      "submit" (handle-submit)
      "session-holder" (handle-session-holder)
      "porttyd-wrapper" (handle-porttyd-wrapper)
      (do
        (emit! *err* (str (usage) "\n"))
        1))))

(System/exit (-main *command-line-args*))
