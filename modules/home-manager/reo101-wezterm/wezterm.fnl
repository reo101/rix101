(local wezterm (require :wezterm))
(local config (or (and wezterm.config_builder
                       (wezterm.config_builder))
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

(set config.freetype_render_target                     :Light)
(set config.window_background_opacity                  0.8)
(set config.window_background_image                    "")
(set config.window_decorations                         :RESIZE)
(set config.window_close_confirmation                  :NeverPrompt)
(set config.use_resize_increments                      false)
(set config.enable_scroll_bar                          false)
(set config.enable_tab_bar                             false)
(set config.adjust_window_size_when_changing_font_size false)
(set config.window_padding                             {:left   0
                                                        :right  0
                                                        :top    0
                                                        :bottom 0})

;;;;;;;;;;;;;;;;
;;; Keybinds ;;;
;;;;;;;;;;;;;;;;

(fn keybind [mods key action]
  (when (= (type action) :table)
    (set action (wezterm.action action)))
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
