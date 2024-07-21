(local wezterm (require :wezterm))
(local config (if wezterm.config_builder
                  (wezterm.config_builder)
                  {}))

;;;;;;;;;;;;;;;;;;;;
;;; Font Options ;;;
;;;;;;;;;;;;;;;;;;;;

(set config.font
     (wezterm.font "FiraCode Nerd Font Mono"))

(set config.harfbuzz_features
     [:liga
      :cv02 :cv19 :cv25 :cv26 :cv28 :cv30 :cv32
      :ss02 :ss03 :ss05 :ss07 :ss09
      :zero])

;;;;;;;;;;;;;;;;;;;;;;
;;; Window Options ;;;
;;;;;;;;;;;;;;;;;;;;;;

(doto config
  (tset :freetype_render_target    :Light)
  (tset :window_background_opacity 0.8)
  (tset :window_background_image   "")
  (tset :window_decorations        :RESIZE)
  (tset :window_close_confirmation :NeverPrompt)
  (tset :use_resize_increments     false)
  (tset :enable_scroll_bar         false)
  (tset :enable_tab_bar            false)
  (tset :window_padding {:left   0
                         :right  0
                         :top    0
                         :bottom 0})
  (tset :adjust_window_size_when_changing_font_size false))

;;;;;;;;;;;;
;;; Bell ;;;
;;;;;;;;;;;;

(doto config
  (tset :audible_bell :Disabled)
  (tset :visual_bell {}))

;;;;;;;;;;;;;;;;
;;; Keybinds ;;;
;;;;;;;;;;;;;;;;

(fn keybind [mods key action]
  (local action (if (= (type action) :table)
                    (wezterm.action action)
                    ;; else
                    action))
  {: mods
   : key
   : action})

(set config.disable_default_key_bindings true)
(set config.keys
     [;;;;;;;;;;;;;;;;;
      ;;; Clipboard ;;;
      ;;;;;;;;;;;;;;;;;
      (keybind :ALT :c {:CopyTo    :Clipboard})
      (keybind :ALT :v {:PasteFrom :Clipboard})

      ;;;;;;;;;;;;;;;;;
      ;;; Font Size ;;;
      ;;;;;;;;;;;;;;;;;
      (keybind :ALT|SHIFT :UpArrow   :IncreaseFontSize)
      (keybind :ALT|SHIFT :DownArrow :DecreaseFontSize)

      ;;;;;;;;;;;;;;
      ;;; Scroll ;;;
      ;;;;;;;;;;;;;;
      (keybind :ALT :u {:ScrollByPage -1})
      (keybind :ALT :d {:ScrollByPage  1})

      ;;;;;;;;;;;;;;
      ;;; Reload ;;;
      ;;;;;;;;;;;;;;
      (keybind :CTRL|SHIFT :r :ReloadConfiguration)])

;;;;;;;;;;;;;
;;; Links ;;;
;;;;;;;;;;;;;

(set config.hyperlink_rules
     [;;; Linkify things that look like URLs
      {:regex  "\\b\\w+://(?:www\\.)?[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-zA-Z0-9()]{1,6}\\b(?:[-a-zA-Z0-9()@:%_\\+.~#?&/=]*)"
       :format "$0"}

      ;;; Linkify things that look like emails
      {:regex "\\b\\w+@[\\w-]+(\\.[\\w-]+)+\\b"
       :format "mailto:$0"}

      ;;; file:// URI
      {:regex "\\bfile://\\S*\\b"
       :format "$0"}])

config
