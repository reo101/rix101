(local colors (require :colors))
(local icons (require :icons))
(local settings (require :settings))

(_G.sbar.add :item {:width 5})
(local apple
       (_G.sbar.add
         :item
         {:icon {:font {:size 16.0}
                 :string icons.apple
                 :padding_left 8
                 :padding_right 8}
          :label {:drawing false}
          :background {:color colors.bg2
                       :border_width 1
                       :border_color colors.black}
          :padding_left 1
          :padding_right 1
          :click_script "$CONFIG_DIR/helpers/menus/bin/menus -s 0"}))
(_G.sbar.add
  :bracket
  [apple.name]
  {:background {:border_color colors.grey
                :color colors.transparent
                :height 30}})
(_G.sbar.add :item {:width 7})
