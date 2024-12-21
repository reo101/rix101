(local icons (require :icons))
(local colors (require :colors))

(local whitelist {:Music true
                  :Spotify true
                  :Firefox true})

(local media-cover
       (_G.sbar.add
         :item
         {:position :right
          :background {:color colors.transparent
                       :image {:string :media.artwork
                               :scale 0.85}}
          :label {:drawing false}
          :icon {:drawing false}
          :drawing false
          :updates true
          :popup {:align :center
                  :horizontal true}}))
(local media-artist
       (_G.sbar.add
         :item
         {:position :right
          :drawing false
          :padding_left 3
          :padding_right 0
          :width 0
          :icon {:drawing false}
          :label {:width 0
                  :font {:size 9}
                  :color (colors.with-alpha colors.white 0.6)
                  :max_chars 18
                  :y_offset 6}}))
(local media-title
       (_G.sbar.add
         :item
         {:position :right
          :drawing false
          :padding_left 3
          :padding_right 0
          :icon {:drawing false}
          :label {:font {:size 11}
                  :width 0
                  :max_chars 16
                  :y_offset (- 5)}}))
(_G.sbar.add
  :item
  {:position (.. :popup. media-cover.name)
   :icon {:string icons.media.back}
   :label {:drawing false}
   :click_script "nowplaying-cli previous"})
(_G.sbar.add
  :item
  {:position (.. :popup. media-cover.name)
   :icon {:string icons.media.play_pause}
   :label {:drawing false}
   :click_script "nowplaying-cli togglePlayPause"})
(_G.sbar.add
  :item
  {:position (.. :popup. media-cover.name)
   :icon {:string icons.media.forward}
   :label {:drawing false}
   :click_script "nowplaying-cli next"})

(var interrupt 0)
(fn animate-detail [detail]
  (when (not detail)
    (set interrupt (- interrupt 1)))
  (when (and (> interrupt 0)
             (not detail))
    (lua "return "))
  (_G.sbar.animate
    :tanh
    30
    #(do
       (media-title:set  {:label {:width (or (and detail :dynamic) 0)}})
       (media-artist:set {:label {:width (or (and detail :dynamic) 0)}}))))

(media-cover:subscribe
  :media_change
  (fn [env]
    (when (. whitelist env.INFO.app)
      (local drawing (= env.INFO.state :playing))
      (media-title:set  {: drawing :label env.INFO.title})
      (media-artist:set {: drawing :label env.INFO.artist})
      (media-cover:set  {: drawing})
      (if drawing
          (do
            (animate-detail true)
            (set interrupt (+ interrupt 1))
            (_G.sbar.delay 5 animate-detail))
          ;; else
          (media-cover:set {:popup {:drawing false}})))))
(media-cover:subscribe
  :mouse.entered
  (fn [env]
    (set interrupt (+ interrupt 1))
    (animate-detail true)))
(media-cover:subscribe
  :mouse.exited
  (fn [env]
    (animate-detail false)))
(media-cover:subscribe
  :mouse.clicked
  (fn [env]
    (media-cover:set {:popup {:drawing :toggle}})))
(media-title:subscribe
  :mouse.exited.global
  (fn [env]
    (media-cover:set {:popup {:drawing false}})))
