(var status nil)
(var busy false)
(var error-message nil)
(var open false)

(fn decode-status [text]
  (let [(decoded _error) (noctalia.json.decode text)]
    (when (and (= (type decoded) "table") (= decoded.schema_version 1))
      decoded)))

(fn role-label [role]
  (if (= role "wifi") "Wi-Fi" "Ethernet"))

(fn role-glyph [role]
  (if (= role "wifi") "wifi" "ethernet"))

(fn current-profile []
  (when (and (not= status nil) (= (type status.profiles) "table") (> (length status.profiles) 0))
    (var selected nil)
    (when (not= status.active nil)
      (each [_ profile (ipairs status.profiles)]
        (when (= profile.name status.active.profile)
          (set selected profile))))
    (or selected (. status.profiles 1))))

(fn path-row [path active-role]
  (let [active (= path.role active-role)
        ready-text (if active
                       "Active"
                       path.ready
                       (if (not= path.management_ip nil)
                           (.. "Ready · " path.management_ip)
                           "Ready")
                       (or path.reason "Unavailable"))]
    (ui.row
      {:align "center" :gap 10 :padding 10 :fill "surface_variant/0.4" :radius 8}
      [(ui.glyph
         {:name (role-glyph path.role)
          :size 22
          :color (if active "primary" path.ready "on_surface" "on_surface_variant")})
       (ui.column
         {:gap 2 :flexGrow 1}
         [(ui.label {:text (role-label path.role) :fontWeight "medium"})
          (ui.label
            {:text ready-text
             :fontSize 11
             :color (if active "primary" path.ready "on_surface_variant" "error")
             :maxLines 1})])
       (ui.button
         {:text (if active "Active" "Switch")
          :variant (if active "primary" "outline")
          :controlSize "sm"
          :enabled (and path.ready (not active) (not busy))
          :onClick (if (= path.role "wifi") "useWifi" "useEthernet")})])))

(fn render []
  (let [profile (current-profile)
          active-role (if (= status nil) nil (if (= status.active nil) nil status.active.role))
          children
          [(ui.row
             {:align "center" :gap 8}
             [(ui.glyph {:name "route" :size 21 :color "primary"})
              (ui.label {:text "Netpath" :fontSize 17 :fontWeight "bold" :flexGrow 1})
              (ui.button {:glyph "refresh" :variant "ghost" :tooltip "Refresh" :onClick "refresh"})
              (ui.button {:glyph "close" :variant "ghost" :tooltip "Close" :onClick "closePanel"})])]]

      (if (= profile nil)
          (table.insert
            children
            (ui.column
              {:flexGrow 1 :align "center" :justify "center" :gap 8}
              [(ui.glyph {:name "alert-triangle" :size 30 :color "error"})
               (ui.label {:text "Netpath status unavailable" :color "error"})]))
          (do
            (table.insert
              children
              (ui.column
                {:gap 3 :padding 10 :fill "primary/0.12" :radius 8}
                [(ui.label {:text "Application address" :fontSize 11 :color "on_surface_variant"})
                 (ui.label {:text profile.vip :fontSize 16 :fontWeight "bold"})
                 (ui.label
                   {:text (if (= active-role nil)
                              "Ordinary routing"
                              (.. "Active on " (role-label active-role)))
                    :fontSize 11
                    :color (if (= active-role nil) "on_surface_variant" "primary")})]))
            (each [_ path (ipairs profile.paths)]
              (table.insert children (path-row path active-role)))))

      (when (not= error-message nil)
        (table.insert
          children
          (ui.label {:text error-message :color "error" :maxLines 3 :textAlign "center"})))

      (table.insert children (ui.separator {}))
      (table.insert
        children
        (ui.row
          {:align "center" :gap 8}
          [(ui.button
             {:text (if busy "Switching…" "Auto")
              :glyph "route"
              :variant "outline"
              :flexGrow 1
              :enabled (not busy)
              :onClick "useAuto"})
           (ui.button
             {:text "Off"
              :glyph "route-off"
              :variant "ghost"
              :enabled (and (not busy) (not= active-role nil))
              :onClick "turnOff"})]))
      (table.insert
        children
        (ui.label
          {:text "Connect the target first; disconnect the old link after switching"
           :fontSize 10
           :color "on_surface_variant"
           :textAlign "center"
           :maxLines 2}))

      (panel.render (ui.column {:padding 14 :gap 10 :flexGrow 1} children))))

(fn refresh! []
  (let [started
        (noctalia.runAsync
          "netpath status --json"
          (fn [result]
            (if (= result.exitCode 0)
                (let [decoded (decode-status result.stdout)]
                  (if (= decoded nil)
                      (set error-message "Netpath returned invalid status")
                      (do
                        (set status decoded)
                        (noctalia.state.set "statusJson" result.stdout))))
                (set error-message (or (noctalia.string.trim result.stderr) "Netpath status failed")))
            (when open (render))))]
    (when (not started)
      (set error-message "Could not start netpath")
      (when open (render)))))

(fn run-action! [action]
  (when (not busy)
    (set busy true)
    (set error-message nil)
    (render)
    (let [started
          (noctalia.runAsync
            (.. "sudo -n netpath " action)
            (fn [result]
              (set busy false)
              (if (= result.exitCode 0)
                  (set error-message nil)
                  (do
                    (set error-message (noctalia.string.trim result.stderr))
                    (when (= error-message "")
                      (set error-message (.. "netpath " action " failed")))
                    (noctalia.notifyError "Netpath" error-message)))
              (refresh!)))]
      (when (not started)
        (set busy false)
        (set error-message "Could not start netpath")
        (render)))))

(noctalia.state.watch
  "statusJson"
  (fn [value]
    (when (= (type value) "string")
      (let [decoded (decode-status value)]
        (when (not= decoded nil)
          (set status decoded)
          (when open (render)))))))

(global refresh #(do (set error-message nil) (refresh!)))
(global useWifi #(run-action! "wifi"))
(global useEthernet #(run-action! "ethernet"))
(global useAuto #(run-action! "auto"))
(global turnOff #(run-action! "off"))
(global closePanel #(panel.close))
(global onOpen #(do (set open true) (render) (refresh!)))
(global onClose #(set open false))
