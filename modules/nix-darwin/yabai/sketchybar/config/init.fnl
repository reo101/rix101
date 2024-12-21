(comment
  (set package.cpath
       (.. (let [sbarlua "/nix/store/hf1cxs7rsqj0kdlzmnahgqq7ray8zac4-lua5.2-SBarLua-0-unstable-2024-08-12"
                 module-path "lib/lua/lua5.2"]
             (string.format
               "%s/%s/?.so;"
               sbarlua
               module-path))
           "./?.fnl;"
           "./?/init.fnl;"
           package.cpath))

  (print package.cpath))

(set _G.sbar (require :sketchybar))

;; (sbar.exec
;;   "sleep 5 && echo TEST"
;;   (fn [result exit-code] (print result)))

(_G.sbar.begin_config)

(require :bar)
(require :default)
(require :items)

(_G.sbar.hotload true)

(_G.sbar.end_config)

(_G.sbar.event_loop)
