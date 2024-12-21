(local colors (require :colors))
(local icons (require :icons))
(local settings (require :settings))
(local app-icons (require :helpers.app-icons))
(local spaces {})
(for [i 1 10]
  (local space
         (_G.sbar.add
           :space
           (.. :space. i)
           {:space i
            :icon {:color colors.white
                   :font {:family settings.font.numbers}
                   :highlight_color colors.red
                   :padding_left 15
                   :padding_right 8
                   :string i}
            :label {:color colors.grey
                    :font "sketchybar-app-font:Regular:16.0"
                    :highlight_color colors.white
                    :padding_right 20
                    :y_offset (- 1)}
            :padding_left 1
            :padding_right 1
            :background {:color colors.bg1
                         :height 26
                         :border_width 1
                         :border_color colors.black}
            :popup {:background {:border_width 5
                                 :border_color colors.black}}}))
  (tset spaces i space)
  (local space-bracket
         (_G.sbar.add
           :bracket
           [space.name]
           {:background
             {:border_color colors.bg2
              :border_width 2
              :color colors.transparent
              :height 28}}))
  (_G.sbar.add
    :space
    (.. :space.padding. i)
    {:script ""
     :space i
     :width settings.group_paddings})
  (local space-popup
         (_G.sbar.add
           :item
           {:background {:drawing true
                         :image {:corner_radius 9 :scale 0.2}}
            :padding_left 5
            :padding_right 0
            :position (.. :popup. space.name)}))
  (space:subscribe
    :space_change
    (fn [env]
      (let [selected (= env.SELECTED :true)
            color (or (and selected colors.grey) colors.bg2)]
        (space:set
          {:background {:border_color (or (and selected
                                               colors.black)
                                          colors.bg2)}
           :icon {:highlight selected}
           :label {:highlight selected}})
        (space-bracket:set
          {:background {:border_color (or (and selected
                                               colors.grey)
                                          colors.bg2)}}))))
  (space:subscribe
    :mouse.clicked
    (fn [env]
      (if (= env.BUTTON :other)
          (do
            (space-popup:set {:background {:image (.. :space. env.SID)}})
            (space:set {:popup {:drawing :toggle}}))
          (let [op (if (= env.BUTTON :right)
                       :--destroy
                       :--focus)]
            (_G.sbar.exec (.. "yabai -m space " op " " env.SID))))))
  (space:subscribe
    :mouse.exited
    #(space:set {:popup {:drawing false}})))
(local space-window-observer
       (_G.sbar.add :item {:drawing false :updates true}))
(local spaces-indicator
       (_G.sbar.add
         :item
         {:background {:border_color (colors.with-alpha colors.bg1
                                       0.0)
                       :color (colors.with-alpha colors.grey
                                0.0)}
          :icon {:color colors.grey
                 :padding_left 8
                 :padding_right 9
                 :string icons.switch.on}
          :label {:color colors.bg1
                  :padding_left 0
                  :padding_right 8
                  :string :Spaces
                  :width 0}
          :padding_left (- 3)
          :padding_right 0}))
(space-window-observer:subscribe
  :space_windows_change
  (fn [env]
    (var icon-line "")
    (var no-app true)
    (each [app count (pairs env.INFO.apps)]
      (set no-app false)
      (local lookup (. app-icons app))
      (local icon
             (if (= lookup nil)
                 (. app-icons :Default)
                 lookup))
      (set icon-line (.. icon-line icon)))
    (when no-app (set icon-line " —"))
    (_G.sbar.animate :tanh 10
                  (fn []
                    (: (. spaces env.INFO.space)
                       :set {:label icon-line})))))
(spaces-indicator:subscribe
  :swap_menus_and_spaces
  (fn [env]
    (let [currently-on (= (. (spaces-indicator:query)
                             :icon :value)
                          icons.switch.on)]
      (spaces-indicator:set {:icon (if currently-on
                                       icons.switch.off
                                       icons.switch.on)}))))
(spaces-indicator:subscribe
  :mouse.entered
  (fn [env]
    (_G.sbar.animate
      :tanh
      30
      #(spaces-indicator:set
         {:background {:border_color {:alpha 1.0}
                       :color {:alpha 1.0}}
          :icon {:color colors.bg1}
          :label {:width :dynamic}}))))
(spaces-indicator:subscribe
  :mouse.exited
  (fn [env]
    (_G.sbar.animate
      :tanh
      30
      #(spaces-indicator:set
         {:background {:border_color {:alpha 0.0}
                       :color {:alpha 0.0}}
          :icon {:color colors.grey}
          :label {:width 0}}))))
(spaces-indicator:subscribe
  :mouse.clicked
  (fn [env]
    (_G.sbar.trigger :swap_menus_and_spaces)))
