#!/usr/bin/env bb

(ns battery.notify
  (:require [clojure.string :as str]
            [babashka.process :refer [shell]]
            [babashka.cli :as cli]
            [babashka.fs :as fs]))

;; ---------------------------
;; Default config
;; ---------------------------
(def default-opts
  (let [parse-env-or-default #(if-let [env (System/getenv %1)] (parse-long env) %2)]
    {:battery  (System/getenv "BATTERY")
     :critical (parse-env-or-default "BATTERY_CRITICAL" 10)
     :low      (parse-env-or-default "BATTERY_LOW" 20)
     :mid      (parse-env-or-default "BATTERY_MID" 40)
     :timeout  (parse-env-or-default "BATTERY_TIMEOUT" 30)}))

(def cli-spec
  {:battery {:desc "Battery name (e.g. BAT0 or macsmc-battery)"}
   :critical {:desc "Critical battery threshold" :coerce :long}
   :low {:desc "Low battery threshold" :coerce :long}
   :mid {:desc "Mid battery threshold" :coerce :long}
   :debug-level {:desc "Debug: hardcoded battery level (0-100)" :coerce :long}})

(def opts
  (merge default-opts (cli/parse-opts *command-line-args* {:spec cli-spec})))

;; ---------------------------
;; Battery detection
;; ---------------------------
(defn battery-device-names []
  (->> (fs/list-dir "/sys/class/power_supply")
       (map fs/file-name)))

(defn has-capacity-file? [dev]
  (fs/exists? (fs/path "/sys/class/power_supply" dev "capacity")))

(defn detect-battery []
  (or
    ;; prefer something with 'battery' or 'bat' and has capacity
    (->> (battery-device-names)
         (filter has-capacity-file?)
         (filter #(re-matches #".*(?i)(battery|bat).*" %))
         first)
    ;; fallback: any device with a capacity file
    (->> (battery-device-names)
         (filter has-capacity-file?)
         first)))

(def battery-name
  (or (:battery opts) (detect-battery)))

(when (nil? battery-name)
  (println "ERROR: No battery detected!")
  (System/exit 1))

(def battery-path
  (str (fs/path "/sys/class/power_supply" battery-name)))

(defn read-battery-file [file]
  (try
    (-> (fs/path battery-path file)
        str
        slurp
        str/trim)
    (catch Exception _
      (do
        (println (str "ERROR: Cannot read " file " from " battery-path))
        nil))))

(defn notify
  [urgency title message]
  (shell ["notify-send"
          "--app-name=Battery"
          (str "--urgency=" (name urgency))
          title message]))

;; ---------------------------
;; Notification logic
;; ---------------------------
(defn handle-critical [level]
  (notify :critical "CRITICAL" "Battery level critical, plug it in now!")

  ;; Poll battery status every second for timeout period
  (let [second-ms  1000
        timeout-ms (* (:timeout opts) second-ms)
        start-time (System/currentTimeMillis)]
    (loop []
      (let [elapsed (- (System/currentTimeMillis) start-time)
            status (read-battery-file "status")]

        (if (>= elapsed timeout-ms)
          ;; Timeout reached
          (notify :critical "CRITICAL" "Laptop will die in 3, 2, 1, ...")

          ;; Check if charging
          (if (= "Charging" status)
            ;; Laptop is now charging - notify and exit
            (notify :normal
                    "Achievement unlocked: living on the edge"
                    (str "Plug your laptop in on "
                         (:critical opts)
                         "% or less battery-capacity"))

            ;; Still discharging - sleep 1s and retry
            (do
              (Thread/sleep second-ms)
              (recur))))))))

(defn handle-low [level]
  (notify :critical "Battery getting real low now..." (str level "% remaining. Time to charge!")))

(defn handle-mid [level]
  (notify :normal "Battery starting to get low..." (str level "% remaining. Consider charging soon.")))

(defn handle-plugged-not-charging [level]
  (notify :critical "Plugged in but not charging!" (str "System overloaded at " level "% battery. Let it cool down.")))

(defn is-plugged-in? []
  (try
    (let [acad-path (str (fs/path "/sys/class/power_supply" "ACAD" "online"))]
      (= "1" (str/trim (slurp acad-path))))
    (catch Exception _
      false)))

(defn battery-notify []
  (let [level (if-let [debug (:debug-level opts)]
                (do (println (str "DEBUG: Using hardcoded level " debug)) debug)
                (when-let [capacity-str (read-battery-file "capacity")]
                  (parse-long capacity-str)))
        status (if (:debug-level opts) "Discharging" (read-battery-file "status"))
        plugged (is-plugged-in?)]
    (cond
      (nil? status)
      (println "ERROR: Cannot read battery status")

      (nil? level)
      (println "ERROR: Cannot read battery capacity")

      (and plugged (not= "Charging" status) (< level 95))
      (do
        (println {:status status :level level :plugged true})
        (handle-plugged-not-charging level))

      (= status "Discharging")
      (do
        (println {:status status :level level})
        (cond
          (<= level (:critical opts)) (handle-critical level)
          (<= level (:low opts))      (handle-low level)
          (<= level (:mid opts))      (handle-mid level))))))

(battery-notify)
