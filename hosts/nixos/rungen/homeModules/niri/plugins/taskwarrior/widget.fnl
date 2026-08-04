(local PANEL_ID "reo101/taskwarrior:panel")
(var pending nil)
(var refreshing false)

(fn render! []
  (barWidget.setGlyph "list-check")
  (if (= pending nil)
      (do
        (barWidget.setGlyphColor "error")
        (barWidget.setTooltip "Taskwarrior unavailable"))
      (do
        (barWidget.setGlyphColor (if (> pending 0) "primary" "on_surface"))
        (barWidget.setTooltip
          (string.format "%d ready task%s" pending (if (= pending 1) "" "s"))))))

(fn refresh! []
  (when (not refreshing)
    (set refreshing true)
    (let [started
          (noctalia.runAsync
            "task status:pending +READY count"
            (fn [result]
              (set refreshing false)
              (if (= result.exitCode 0)
                  (do
                    (set pending (tonumber (noctalia.string.trim result.stdout)))
                    (noctalia.state.set "readyCount" pending))
                  (set pending nil))
              (render!)))]
      (when (not started)
        (set refreshing false)
        (set pending nil)
        (render!)))))

(noctalia.state.watch
  "readyCount"
  (fn [value]
    (set pending (tonumber value))
    (render!)))

(global update (fn [] (refresh!)))
(global onClick (fn [] (noctalia.togglePanel PANEL_ID)))

(noctalia.setUpdateInterval 30000)
(render!)
(refresh!)
