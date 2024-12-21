(local colors (require :colors))
(local settings (require :settings))

(local front-app
       (_G.sbar.add
         :item
         :front_app
         {:display :active
          :icon {:drawing false}
          :label {:font {:style (. settings.font.style-map :Black)
                         :size 12.0}}
          :updates true}))

(front-app:subscribe
  :front_app_switched
  (fn [env]
    (front-app:set {:label {:string env.INFO}})))

(front-app:subscribe
  :mouse.clicked
  (fn [env]
    (_G.sbar.trigger :swap_menus_and_spaces)))
