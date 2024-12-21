(local settings (require :settings))
(local
  icons
  {:nerdfont
     {:apple ""
      :battery {:_0 ""
                :_100 ""
                :_25 ""
                :_50 ""
                :_75 ""
                :charging ""}
      :clipboard "Missing Icon"
      :cpu ""
      :gear ""
      :loading ""
      :media {:back "" :forward "" :play_pause ""}
      :plus ""
      :switch {:off "󱨦" :on "󱨥"}
      :volume {:_0 ""
               :_10 ""
               :_100 ""
               :_33 ""
               :_66 ""}
      :wifi {:connected "󰖩"
             :disconnected "󰖪"
             :download ""
             :router "Missing Icon"
             :upload ""}}
   :sf_symbols
     {:apple "􀣺"
      :battery {:_0 "􀛪"
                :_100 "􀛨"
                :_25 "􀛩"
                :_50 "􀺶"
                :_75 "􀺸"
                :charging "􀢋"}
      :clipboard "􀉄"
      :cpu "􀫥"
      :gear "􀍟"
      :loading "􀖇"
      :media {:back "􀊊"
              :forward "􀊌"
              :play_pause "􀊈"}
      :plus "􀅼"
      :switch {:off "􁏯" :on "􁏮"}
      :volume {:_0 "􀊣"
               :_10 "􀊡"
               :_100 "􀊩"
               :_33 "􀊥"
               :_66 "􀊧"}
      :wifi {:connected "􀙇"
             :disconnected "􀙈"
             :download "􀄩"
             :router "􁓤"
             :upload "􀄨"}}})
(if (not (= settings.icons :NerdFont))
  icons.sf_symbols
  icons.nerdfont)
