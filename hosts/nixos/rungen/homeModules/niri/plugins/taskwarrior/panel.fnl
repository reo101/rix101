(local MAX_ROWS 20)
(local SEARCH_DEBOUNCE_TICKS 2)
(var tasks [])
(var loading false)
(var error-message nil)
(var selected-task nil)
(var search-text "")
(var search-dirty false)
(var search-ticks 0)
(var render nil)

(fn task-date [value]
  (when (and (= (type value) "string") (>= (length value) 8))
    (.. (string.sub value 1 4)
        "-"
        (string.sub value 5 6)
        "-"
        (string.sub value 7 8))))

(fn shell-quote [value]
  (.. "'" (string.gsub (tostring value) "'" "'\\''") "'"))

(fn link-url [value]
  (when (= (type value) "string")
    (let [text (noctalia.string.trim value)]
      (when (not= (string.match text "^https?://%S+$") nil)
        text))))

(fn search-argument [query]
  (if (= query "")
      ""
      (not= (string.match query "^[-+]%S+$") nil)
      (.. " " (shell-quote query))
      (.. " " (shell-quote (.. "/" (string.gsub query "/" "\\/") "/")))))

(fn subtitle [task]
  (let [parts []]
    (when (not= task.id nil)
      (table.insert parts (.. "#" (tostring task.id))))
    (when (and (= (type task.project) "string") (not= task.project ""))
      (table.insert parts task.project))
    (let [due (task-date task.due)]
      (when (not= due nil)
        (table.insert parts (.. "due " due))))
    (table.insert parts (string.format "urgency %.1f" (or (tonumber task.urgency) 0)))
    (table.concat parts "  ·  ")))

(fn task-row [task index]
  (let [urgency (or (tonumber task.urgency) 0)
        color (if (>= urgency 10)
                  "error"
                  (>= urgency 5)
                  "secondary"
                  "primary")]
    (ui.column
      {:key (if (= (type task.uuid) "string") task.uuid (tostring index))
       :gap 3
       :padding 10
       :fill "surface_variant/0.45"
       :radius 8
       :onClick (fn []
                  (set selected-task task)
                  (render))}
      [(ui.row
         {:align "center" :gap 6}
         [(ui.label
            {:text (if (= (type task.description) "string")
                       task.description
                       "(untitled)")
             :fontWeight "medium"
             :maxLines 2
             :flexGrow 1})
          (ui.glyph {:name "chevron-right" :size 15 :color "on_surface_variant"})])
       (ui.label
         {:text (subtitle task)
          :fontSize 11
          :color color
          :maxLines 1})])))

(fn detail-field [field-label value]
  (ui.row
    {:gap 8 :align "start"}
    [(ui.label {:text field-label :width 72 :fontSize 11 :color "on_surface_variant"})
     (ui.label {:text value :flexGrow 1 :maxLines 3})]))

(fn annotation-node [annotation index]
  (let [text (if (= (type annotation.description) "string") annotation.description "")
        url (link-url text)
        entry (task-date annotation.entry)
        children []]
    (if (not= url nil)
        (table.insert
          children
          (ui.button
            {:key (.. "annotation-link-" (tostring index))
             :text url
             :glyph "external-link"
             :width 358
             :contentAlign "start"
             :variant "outline"
             :tooltip url
             :onClick (fn []
                        (let [started (noctalia.runAsync (.. "xdg-open " (shell-quote url)))]
                          (when (not started)
                            (noctalia.notifyError "Taskwarrior" "Could not open link"))))}))
        (table.insert
          children
          (ui.label {:text (if (not= text "") text "(empty annotation)") :maxLines 0})))
    (when (not= entry nil)
      (table.insert children (ui.label {:text entry :fontSize 10 :color "on_surface_variant"})))
    (ui.column
      {:key (.. "annotation-" (tostring index))
       :gap 4
       :padding 8
       :fill "surface_variant/0.35"
       :radius 7}
      children)))

(fn render-list []
  (let [query (noctalia.string.trim search-text)
        body []]
    (if loading
        (table.insert
          body
          (ui.column
            {:flexGrow 1 :align "center" :justify "center" :gap 8}
            [(ui.glyph {:name "loader" :size 28 :color "primary"})
             (ui.label {:text "Loading tasks…" :color "on_surface_variant"})]))
        (not= error-message nil)
        (table.insert
          body
          (ui.column
            {:flexGrow 1 :align "center" :justify "center" :gap 8}
            [(ui.glyph {:name "alert-circle" :size 28 :color "error"})
             (ui.label {:text error-message :color "error" :maxLines 3 :textAlign "center"})]))
        (= (length tasks) 0)
        (table.insert
          body
          (ui.column
            {:flexGrow 1 :align "center" :justify "center" :gap 8}
            [(ui.glyph {:name "circle-check" :size 32 :color "primary"})
             (ui.label {:text (if (= query "") "No ready tasks" "No matching tasks")})]))
        (let [rows []]
          (for [index 1 (math.min (length tasks) MAX_ROWS)]
            (table.insert rows (task-row (. tasks index) index)))
          (table.insert body (ui.scroll {:flexGrow 1 :gap 7} rows))))

    (let [result-label (if (= query "")
                           (.. (tostring (length tasks)) " ready")
                           (.. (tostring (length tasks)) " matches"))]
      (var footer "Read-only overview")
      (if (not= query "")
          (set footer "Taskwarrior search")
          (> (length tasks) MAX_ROWS)
          (set footer (string.format "Showing %d of %d" MAX_ROWS (length tasks))))

      (panel.render
        (ui.column
          {:padding 14 :gap 10 :flexGrow 1}
          [(ui.row
             {:align "center" :gap 8}
             [(ui.glyph {:name "list-check" :size 20 :color "primary"})
              (ui.label {:text "Taskwarrior" :fontSize 17 :fontWeight "bold" :flexGrow 1})
              (ui.label {:text result-label :color "on_surface_variant"})
              (ui.button {:glyph "refresh" :variant "ghost" :tooltip "Refresh" :onClick "refresh"})
              (ui.button {:glyph "close" :variant "ghost" :tooltip "Close" :onClick "closePanel"})])
           (ui.row
             {:align "center" :gap 7}
             [(ui.glyph {:name "search" :size 16 :color "on_surface_variant"})
              (ui.input
                {:key "task-search"
                 :value search-text
                 :placeholder "Search regex or +tag…"
                 :controlSize "sm"
                 :focus true
                 :flexGrow 1
                 :onChange "onSearchChanged"
                 :onSubmit "onSearchSubmitted"})])
           (ui.separator {})
           (ui.column {:flexGrow 1} body)
           (ui.separator {})
           (ui.row
             {:align "center" :gap 8}
             [(ui.label {:text footer :fontSize 11 :color "on_surface_variant" :flexGrow 1})
              (ui.button
                {:text "Open task next"
                 :glyph "terminal-2"
                 :controlSize "sm"
                 :onClick "openTerminal"})])])))))

(fn render-detail []
  (let [task selected-task
        fields [(detail-field "Status" (tostring (or task.status "pending")))
                (detail-field "Urgency" (string.format "%.1f" (or (tonumber task.urgency) 0)))]]
    (when (and (= (type task.project) "string") (not= task.project ""))
      (table.insert fields (detail-field "Project" task.project)))
    (when (and (= (type task.tags) "table") (> (length task.tags) 0))
      (table.insert fields (detail-field "Tags" (table.concat task.tags ", "))))
    (let [due (task-date task.due)]
      (when (not= due nil)
        (table.insert fields (detail-field "Due" due))))
    (let [entered (task-date task.entry)]
      (when (not= entered nil)
        (table.insert fields (detail-field "Entered" entered))))
    (let [modified (task-date task.modified)]
      (when (not= modified nil)
        (table.insert fields (detail-field "Modified" modified))))

    (let [content
          [(ui.column
             {:gap 5 :padding 10 :fill "surface_variant/0.45" :radius 8}
             [(ui.label {:text "Description" :fontSize 11 :color "on_surface_variant"})
              (ui.label
                {:text (if (= (type task.description) "string") task.description "(untitled)")
                 :fontSize 15
                 :fontWeight "medium"
                 :maxLines 0})])
           (ui.column {:gap 6 :padding 10 :fill "surface_variant/0.30" :radius 8} fields)
           (ui.label {:text "Annotations" :fontSize 13 :fontWeight "bold"})]
          annotations (if (= (type task.annotations) "table") task.annotations [])]
      (if (= (length annotations) 0)
          (table.insert content (ui.label {:text "No annotations" :color "on_surface_variant"}))
          (each [index annotation (ipairs annotations)]
            (table.insert content (annotation-node annotation index))))

      (panel.render
        (ui.column
          {:padding 14 :gap 10 :flexGrow 1}
          [(ui.row
             {:align "center" :gap 8}
             [(ui.button
                {:glyph "arrow-left" :variant "ghost" :tooltip "Back" :onClick "showTaskList"})
              (ui.label
                {:text (if (not= task.id nil) (.. "Task #" (tostring task.id)) "Task details")
                 :fontSize 17
                 :fontWeight "bold"
                 :flexGrow 1})
              (ui.button {:glyph "close" :variant "ghost" :tooltip "Close" :onClick "closePanel"})])
           (ui.separator {})
           (ui.scroll {:flexGrow 1 :gap 8} content)
           (ui.separator {})
           (ui.row
             {:align "center" :gap 8}
             [(ui.label
                {:text "Read-only details" :fontSize 11 :color "on_surface_variant" :flexGrow 1})
              (ui.button
                {:text "Open in terminal"
                 :glyph "terminal-2"
                 :controlSize "sm"
                 :onClick "openSelectedInTerminal"})])])))))

(set render
  (fn []
    (if (not= selected-task nil)
        (render-detail)
        (render-list))))

(fn refresh! []
  (when (not loading)
    (let [query (noctalia.string.trim search-text)]
      (set search-dirty false)
      (set search-ticks 0)
      (set loading true)
      (set error-message nil)
      (render)

      (let [command (.. "task status:pending +READY" (search-argument query) " export")
            started
            (noctalia.runAsync
              command
              (fn [result]
                (set loading false)
                (if (not= query (noctalia.string.trim search-text))
                    (do
                      (set search-dirty true)
                      (set search-ticks 0))
                    (not= result.exitCode 0)
                    (do
                      (set tasks [])
                      (set error-message (noctalia.string.trim result.stderr))
                      (when (= error-message "")
                        (set error-message "Taskwarrior export failed"))
                      (render))
                    (let [(decoded decode-error) (noctalia.json.decode result.stdout)]
                      (if (not= (type decoded) "table")
                          (do
                            (set tasks [])
                            (set error-message (or decode-error "Taskwarrior returned invalid JSON"))
                            (render))
                          (do
                            (set tasks decoded)
                            (table.sort
                              tasks
                              (fn [a b]
                                (let [left (or (tonumber a.urgency) 0)
                                      right (or (tonumber b.urgency) 0)]
                                  (if (= left right)
                                      (< (tostring (or a.description ""))
                                         (tostring (or b.description "")))
                                      (> left right)))))
                            (when (= query "")
                              (noctalia.state.set "readyCount" (length tasks)))
                            (render)))))))]
        (when (not started)
          (set loading false)
          (set error-message "Could not start Taskwarrior")
          (render))))))

(global refresh refresh!)

(fn change-search! [value]
  (set search-text (or value ""))
  (set search-dirty true)
  (set search-ticks 0))

(global onSearchChanged change-search!)
(global onSearchSubmitted
  (fn [value]
    (change-search! value)
    (when (not loading)
      (refresh!))))

(global update
  (fn []
    (when (and search-dirty (not loading))
      (set search-ticks (+ search-ticks 1))
      (when (>= search-ticks SEARCH_DEBOUNCE_TICKS)
        (refresh!)))))

(global showTaskList
  (fn []
    (set selected-task nil)
    (render)))

(global openTerminal
  (fn []
    (noctalia.runInTerminal "task next; printf '\\nPress Enter to close…'; read _")))

(global openSelectedInTerminal
  (fn []
    (when (and (not= selected-task nil) (= (type selected-task.uuid) "string"))
      (noctalia.runInTerminal
        (.. "task "
            (shell-quote selected-task.uuid)
            " information; printf '\\nPress Enter to close…'; read _")))))

(global closePanel (fn [] (panel.close)))

(global onOpen
  (fn [_context]
    (set selected-task nil)
    (render)
    (refresh!)))

(global onClose (fn [] (set selected-task nil)))

(noctalia.setUpdateInterval 250)
