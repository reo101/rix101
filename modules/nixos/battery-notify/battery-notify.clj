#!/usr/bin/env bb

(ns battery.notify
  (:require [clojure.string :as str]
            [clojure.core.async :as async]
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
   :mid {:desc "Mid battery threshold" :coerce :long}})

(def opts
  (merge default-opts (cli/parse-opts *command-line-args* {:spec cli-spec})))

;; ---------------------------
;; Battery detection
;; ---------------------------
(defn battery-device-names []
  (->> (fs/list-dir "/sys/class/power_supply")
       (map fs/file-name)))

(defn has-capacity-file? [dev]
  (fs/exists? (str "/sys/class/power_supply/" dev "/capacity")))

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

(def battery-path
  (str "/sys/class/power_supply/" battery-name))

(defn read-battery-file [file]
  (-> (slurp (str battery-path "/" file)) str/trim))

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

  ;; Use a promise to block the main thread until our monitoring completes
  (let [done-promise (promise)
        timeout-channel (async/timeout (* (:timeout opts) 1000))]

    ;; Start the monitoring process in a go block
    (async/go
      (loop []
        ;; Create a new check interval for each iteration
        (let [check-interval (async/timeout 1000)
              [_ channel] (async/alts! [timeout-channel check-interval])]

          (if (= channel timeout-channel)
            ;; Timeout reached - the overall waiting period has expired
            (do
              (notify :critical "CRITICAL" "Laptop will die in 3, 2, 1, ...")
              (deliver done-promise false))

            ;; Check interval completed - check battery status and maybe continue
            (let [status (read-battery-file "status")]
              (if (= "Charging" status)
                ;; Laptop is now charging - notify and exit
                (do
                  (notify :low
                          "Achievement unlocked: living on the edge"
                          (str "Plug your laptop in on "
                               (:critical opts)
                               "% or less battery-capacity"))
                  (deliver done-promise true))
                ;; Still discharging - continue the loop for another check
                (recur)))))))

    ;; Block until our promise is delivered (monitoring completes)
    @done-promise))

(defn handle-low [level]
  (notify :critical "Battery getting real low now..." (str level "% remaining. Time to charge!")))

(defn handle-mid [level]
  (notify :critical "Battery starting to get low..." (str level "% remaining. Consider charging soon.")))

(defn battery-notify []
  (let [status (read-battery-file "status")
        level  (parse-long (read-battery-file "capacity"))]
    (println {:status status :level level})
    (when (= status "Discharging")
      (cond
        (<= level (:critical opts)) (handle-critical level)
        (<= level (:low opts))      (handle-low level)
        (<= level (:mid opts))      (handle-mid level)))))

(battery-notify)
