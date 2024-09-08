#!/usr/bin/env bb

(ns sketchybar-config
  (:require [babashka.process :refer [shell]]
            [babashka.cli :as cli]
            [clojure.string :as str]))

(def cli-options {:plugin-dir {}
                  :util-dir {}
                  :get-menu-bar-height {}})

(def args (cli/parse-opts *command-line-args* {:spec cli-options}))

(def plugin-dir (:plugin-dir args))
(def util-dir (:util-dir args))
(def get-menu-bar-height-script (:get-menu-bar-height args))

(def env {"PLUGIN_DIR" plugin-dir
          "UTIL_DIR"   util-dir})

(defn transform-list [coll]
  (loop [items coll
         result []]
    (cond
      (empty? items)
      result

      (and (keyword? (first items)) (nil? (second items)))
      (recur (drop 2 items) result)

      (keyword? (first items))
      (recur (drop 2 items)
             (conj result
                   (str (name (first items))
                        "="
                        (second items))))

      :else
      (recur (rest items) (conj result (first items))))))

(defn run [cmd]
  (->> cmd
       transform-list
       (apply shell {:out :string :extra-env env})
       eval
       :out
       str/trim))

;; Function to get menu bar height
(defn get-menu-bar-height []
  (run [get-menu-bar-height-script]))

;; Dynamic background color based on system appearance
(def background-color
  (let [appearance (run ["defaults" "read" "-g" "AppleInterfaceStyle"])]
    (if (= appearance "Dark")
      "0x502a2d3d"
      "0x50f5f0f5")))

;; Sketchybar command helpers
(defn sketchybar [& args]
  (run (cons "sketchybar" args)))

;; Set up the bar appearance
(defn setup-bar []
  (sketchybar
    "--bar"
    :height (get-menu-bar-height)
    :blur_radius "25"
    :position "top"
    :sticky "on"
    :margin "10"
    :color "0x002a2d3d"
    :notch_offset "5"
    :corner_radius "12"
    :border_color "0x80c4a7e7"
    :border_width "0"))

;;; Changing Defaults ;;;
;; We now change some default values that are applied to all further items
;; For a full list of all available item properties see:
;; https://felixkratz.github.io/SketchyBar/config/items
(defn set-defaults []
  (sketchybar
    "--default"
    :updates "when_shown"
    :icon.font "SF Pro Rounded:Bold:14.0"
    :icon.color "0xffc6ceef"
    :label.font "SF Pro Rounded:Bold:14.0"
    :label.color "0xffc6ceef"
    :padding_left "3"
    :padding_right "3"
    :label.padding_left "4"
    :label.padding_right "4"
    :icon.padding_left "4"
    :icon.padding_right "4"))

;;; Adding Mission Control Space Indicators ;;;
;; Now we add some mission control spaces:
;; https://felixkratz.github.io/SketchyBar/config/components#space----associate-mission-control-spaces-with-an-item
;; to indicate active and available mission control spaces
(defn add-spaces []
  (let [space-icons ["1" "2" "3" "4" "5" "6" "7" "8" "9" "10"]]
    (doseq [i (range (count space-icons))]
      (let [space-id (inc i)
            icon (nth space-icons i)]
        (sketchybar
          "--add" "space" (str "space." space-id) "left"
          "--set" (str "space." space-id)
          :associated_space space-id
          :icon icon
          :background.color "0x44ffffff"
          :background.corner_radius "7"
          :background.height "20"
          :background.drawing "on"
          :background.border_color "0x952a2d3d"
          :background.border_width "1"
          :label.drawing "off"
          :script (str plugin-dir "/space.sh")
          :click_script (str "yabai -m space --focus " space-id))))))

;;; Adding Left Items ;;;
;; We add some regular items to the left side of the bar
;; only the properties deviating from the current defaults need to be set
(defn add-front-app []
  (sketchybar
    "--add" "item" "space_separator" "left"
    "--set" "space_separator"
    :icon "λ"
    :icon.color "0xffff946f"
    :padding_left "10"
    :padding_right "10"
    :label.drawing "off")
  (sketchybar
    "--add" "item" "front_app" "left"
    "--set" "front_app"
    :script (str plugin-dir "/front_app.sh")
    :icon.drawing "off"
    :background.color background-color
    :background.corner_radius "7"
    :blur_radius "30"
    :background.border_color "0x80c4a7e7"
    :background.border_width "1"
    "--subscribe" "front_app" "front_app_switched"))

;;; Adding Right Items ;;;
;; In the same way as the left items we can add items to the right side.
;; Additional position (e.g. center) are available, see:
;; https://felixkratz.github.io/SketchyBar/config/items#adding-items-to-sketchybar
;;
;; Some items refresh on a fixed cycle, e.g. the clock runs its script once
;; every 10s. Other items respond to events they subscribe to, e.g. the
;; volume.sh script is only executed once an actual change in system audio
;; volume is registered. More info about the event system can be found here:
;; https://felixkratz.github.io/SketchyBar/config/events
(defn add-right-items []
  (let [items [{:name "clock"
                :icon "􀐬"
                :script (str plugin-dir "/clock.sh")
                :update-freq 10
                :subscribe []}
               {:name "wifi"
                :icon "􀙇"
                :script (str plugin-dir "/wifi.sh")}
               {:name "volume"
                :script (str plugin-dir "/volume.sh")}
               {:name "battery"
                :script (str plugin-dir "/battery.sh")
                :update_freq 120
                :subscribe ["battery" "system_woke" "power_source_change"]}]]
    (doseq [{:keys [name icon script update-freq subscribe]}
            items]
      ;; NOTE: `apply` because of `subscribe` (a list)
      (apply sketchybar
        "--add" "item" name "right"
        "--set" name
        :script script
        :icon icon
        :update_freq (or update-freq 0)
        :background.color background-color
        :background.corner_radius "7"
        :icon.padding_left "10"
        :label.padding_right "10"
        :blur_radius "30"
        :background.border_color "0x80c4a7e7"
        :background.border_width "1"
        ;; FIXME: ugly
        (if subscribe
          (if (not= subscribe [])
            (cons "--subscribe" subscribe)
            [])
          ["--subscribe" name (str name "_change")])))))


;;; Finalizing Setup ;;;
;; The below command is only needed at the end of the initial configuration to
;; force all scripts to run the first time, it should never be run in an item script.)
(defn finalize []
  (sketchybar "--update"))

;; Main function
(defn main []
  (setup-bar)
  (set-defaults)
  (add-spaces)
  (add-front-app)
  (add-right-items)
  (finalize))

(main)
