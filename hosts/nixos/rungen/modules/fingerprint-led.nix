{ lib, pkgs, config, ... }:

let
  cfg = config.services.fingerprint-led;
in
{
  options.services.fingerprint-led = {
    enable = lib.mkEnableOption "fingerprint LED indicator when waiting for touch";

    ledPath = lib.mkOption {
      type = lib.types.str;
      description = "Path to the LED sysfs interface";
      default = "/sys/class/leds/chromeos:white:power";
    };

    blinkInterval = lib.mkOption {
      type = lib.types.int;
      description = "Blink interval in milliseconds";
      default = 200;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.fprintd.enable;
        message = "services.fingerprint-led requires services.fprintd.enable = true";
      }
    ];

    systemd.services.fingerprint-led = {
      description = "Flash the fingerprint LED while fprintd is waiting for touch";
      wantedBy = [ "multi-user.target" ];
      wants = [ "dbus.service" ];
      after = [ "dbus.service" ];
      path = [
        pkgs.bash
        pkgs.busybox
        pkgs.coreutils
        pkgs.dbus
      ];

      serviceConfig = {
        Restart = "always";
        RestartSec = "2";
        User = "root";
      };

      script = ''
        set -euo pipefail

        blink_interval_ms=${builtins.toString cfg.blinkInterval}
        blink_interval_us=${builtins.toString (cfg.blinkInterval * 1000)}

        led_path=""
        for candidate in \
          ${lib.escapeShellArg cfg.ledPath} \
          /sys/class/leds/chromeos:multicolor:power \
          /sys/class/leds/chromeos:white:power
        do
          if [ -d "$candidate" ]; then
            led_path="$candidate"
            break
          fi
        done

        if [ -z "$led_path" ]; then
          echo "No suitable fingerprint LED path found"
          exit 1
        fi

        trigger_path="$led_path/trigger"
        brightness_path="$led_path/brightness"
        max_brightness_path="$led_path/max_brightness"
        max_brightness="$(cat "$max_brightness_path" 2>/dev/null || echo 255)"
        case "$max_brightness" in
          ""|*[!0-9]*) max_brightness=255 ;;
        esac

        blinking=false
        blink_pid=""
        pending_finger_needed=false
        pending_properties_changed=false
        pending_verify_status=false

        has_trigger() {
          local trigger

          for trigger in $(cat "$trigger_path" 2>/dev/null | tr '[]' '  '); do
            if [ "$trigger" = "$1" ]; then
              return 0
            fi
          done

          return 1
        }

        read_current_trigger() {
          local trigger

          for trigger in $(cat "$trigger_path" 2>/dev/null); do
            case "$trigger" in
              \[*\])
                printf '%s\n' "$trigger" | tr -d '[]'
                return 0
                ;;
            esac
          done

          return 1
        }

        set_trigger() {
          if has_trigger "$1"; then
            printf '%s\n' "$1" > "$trigger_path" 2>/dev/null
          else
            return 1
          fi
        }

        set_brightness() {
          printf '%s\n' "$1" > "$brightness_path" 2>/dev/null
        }

        idle_trigger="$(read_current_trigger 2>/dev/null || true)"
        idle_brightness="$(cat "$brightness_path" 2>/dev/null || true)"

        set_idle() {
          local trigger

          # Prefer the kernel/default power LED trigger when possible. On the
          # Framework ChromeOS-style power LED, chromeos-auto keeps the LED on
          # while awake and lets firmware/kernel policy turn it off for sleep.
          if [ -n "$idle_trigger" ] && [ "$idle_trigger" != "none" ] && set_trigger "$idle_trigger"; then
            return 0
          fi

          for trigger in chromeos-auto default-on; do
            if set_trigger "$trigger"; then
              return 0
            fi
          done

          if set_trigger "none"; then
            if [ -n "$idle_brightness" ]; then
              set_brightness "$idle_brightness" || true
            else
              set_brightness "$max_brightness" || true
            fi
          fi
        }

        stop_software_blink() {
          if [ -z "$blink_pid" ]; then
            return 0
          fi

          if kill -0 "$blink_pid" 2>/dev/null; then
            kill "$blink_pid" 2>/dev/null || true
            wait "$blink_pid" 2>/dev/null || true
          fi

          blink_pid=""
        }

        start_software_blink() {
          (
            trap 'exit 0' TERM INT

            while :; do
              set_brightness "$max_brightness" || true
              busybox usleep "$blink_interval_us" || sleep 0.2
              set_brightness 0 || true
              busybox usleep "$blink_interval_us" || sleep 0.2
            done
          ) &

          blink_pid="$!"
        }

        start_blink() {
          if [ "$blinking" = "true" ]; then
            return 0
          fi

          blinking=true
          echo "Fingerprint waiting for touch, starting LED flash..."

          if set_trigger "timer"; then
            set_brightness "$max_brightness" || true
            printf '%s\n' "$blink_interval_ms" > "$led_path/delay_on" 2>/dev/null || true
            printf '%s\n' "$blink_interval_ms" > "$led_path/delay_off" 2>/dev/null || true
          else
            set_trigger "none" || true
            start_software_blink
          fi
        }

        stop_blink() {
          if [ "$blinking" != "true" ]; then
            return 0
          fi

          stop_software_blink
          set_idle
          blinking=false
          pending_finger_needed=false
          pending_properties_changed=false
          pending_verify_status=false
          echo "Fingerprint verify ended, restoring default LED behavior..."
        }

        cleanup() {
          stop_software_blink
          set_idle
        }

        trap cleanup EXIT
        set_idle

        while IFS= read -r line; do
          case "$line" in
            *"member=VerifyStart"*|*"member=VerifyFingerSelected"*)
              pending_finger_needed=false
              pending_properties_changed=false
              pending_verify_status=false
              start_blink
              ;;
            *"member=VerifyStatus"*)
              pending_finger_needed=false
              pending_properties_changed=false
              pending_verify_status=true
              ;;
            *"member=PropertiesChanged"*)
              pending_finger_needed=false
              pending_properties_changed=true
              pending_verify_status=false
              ;;
            *"string \"finger-needed\""*)
              if [ "$pending_properties_changed" = "true" ]; then
                pending_finger_needed=true
              fi
              ;;
            *"member=VerifyStop"*|*"member=Release"*)
              pending_finger_needed=false
              pending_properties_changed=false
              pending_verify_status=false
              stop_blink
              ;;
            *"member=NameOwnerChanged"*)
              pending_finger_needed=false
              pending_properties_changed=false
              pending_verify_status=false
              stop_blink
              ;;
            *"boolean true"*)
              if [ "$pending_finger_needed" = "true" ]; then
                pending_finger_needed=false
                pending_properties_changed=false
                start_blink
              elif [ "$pending_verify_status" = "true" ]; then
                pending_verify_status=false
                stop_blink
              fi
              ;;
            *"boolean false"*)
              if [ "$pending_finger_needed" = "true" ]; then
                pending_finger_needed=false
                pending_properties_changed=false
                stop_blink
              else
                pending_verify_status=false
              fi
              ;;
          esac
        done < <(
          stdbuf -oL -eL dbus-monitor --system \
            "type='method_call',interface='net.reactivated.Fprint.Device',member='VerifyStart'" \
            "type='method_call',interface='net.reactivated.Fprint.Device',member='VerifyStop'" \
            "type='method_call',interface='net.reactivated.Fprint.Device',member='Release'" \
            "type='signal',interface='net.reactivated.Fprint.Device',member='VerifyFingerSelected'" \
            "type='signal',interface='net.reactivated.Fprint.Device',member='VerifyStatus'" \
            "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='net.reactivated.Fprint.Device'" \
            "type='signal',sender='org.freedesktop.DBus',interface='org.freedesktop.DBus',member='NameOwnerChanged',arg0='net.reactivated.Fprint'"
        )
      '';
    };
  };
}
