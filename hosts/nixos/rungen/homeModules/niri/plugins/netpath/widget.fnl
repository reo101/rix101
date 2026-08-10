(local PANEL_ID "reo101/netpath:panel")
(var status nil)
(var refreshing false)
(var unavailable false)
(var parse-error false)

(fn decode-status [text]
  (let [(decoded _error) (noctalia.json.decode text)]
    (when (and (= (type decoded) "table") (= decoded.schema_version 1))
      decoded)))

(fn render! []
  (if unavailable
      (do
        (barWidget.setGlyph "route-off")
        (barWidget.setGlyphColor "error")
        (barWidget.setTooltip "Netpath unavailable"))
      parse-error
      (do
        (barWidget.setGlyph "route-off")
        (barWidget.setGlyphColor "error")
        (barWidget.setTooltip "Netpath: invalid status data"))
      (= status nil)
      (do
        (barWidget.setGlyph "route")
        (barWidget.setGlyphColor "on_surface_variant")
        (barWidget.setTooltip "Netpath: loading"))
      (= status.active nil)
      (do
        (barWidget.setGlyph "route-off")
        (barWidget.setGlyphColor "on_surface_variant")
        (barWidget.setTooltip "Netpath: ordinary routing"))
      (let [role status.active.role
            label (if (= role "wifi") "Wi-Fi" "Ethernet")]
        (barWidget.setGlyph (if (= role "wifi") "wifi" "ethernet"))
        (barWidget.setGlyphColor "primary")
        (barWidget.setTooltip (.. "Netpath: " status.active.profile " " label)))))

(fn refresh! []
  (when (not refreshing)
    (set refreshing true)
    (let [started
          (noctalia.runAsync
            "netpath status --json"
            (fn [result]
              (set refreshing false)
              (if (= result.exitCode 0)
                  (let [decoded (decode-status result.stdout)]
                    (if (= decoded nil)
                        (do
                          (set status nil)
                          (set unavailable false)
                          (set parse-error true))
                        (do
                          (set status decoded)
                          (set unavailable false)
                          (set parse-error false)
                          (noctalia.state.set "statusJson" result.stdout))))
                  (do
                    (set status nil)
                    (set unavailable true)
                    (set parse-error false)))
              (render!)))]
      (when (not started)
        (set refreshing false)
        (set unavailable true)
        (set parse-error false)
        (render!)))))

(global update refresh!)
(global onClick #(noctalia.togglePanel PANEL_ID))

(noctalia.setUpdateInterval 5000)
(render!)
(refresh!)