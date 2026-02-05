{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.services.fingerprint-led;
in
{
  options.services.fingerprint-led = {
    enable = lib.mkEnableOption "fingerprint LED indicator when waiting for touch";

    ledPath = lib.mkOption {
      type = lib.types.str;
      default = "/sys/class/leds/chromeos:white:power";
      description = "Path to the LED sysfs interface";
    };

    blinkInterval = lib.mkOption {
      type = lib.types.int;
      default = 200;
      description = "Blink interval in milliseconds";
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
      description = "Flash fingerprint LED when waiting for touch";
      wantedBy = [ "fprintd.service" ];
      after = [ "fprintd.service" ];

      serviceConfig = {
        User = "root";
        Restart = "always";
        RestartSec = "5";
        ExecStart = pkgs.writeShellScript "fingerprint-led" ''
          set -eu

          LED_PATH="${cfg.ledPath}"
          BLINK_INTERVAL="${builtins.toString cfg.blinkInterval}"

          # Check if LED path exists
          if [ ! -d "$LED_PATH" ]; then
            echo "LED path $LED_PATH not found, trying alternatives..."
            for alt in /sys/class/leds/chromeos:multicolor:power /sys/class/leds/chromeos:white:power; do
              if [ -d "$alt" ]; then
                LED_PATH="$alt"
                echo "Using $LED_PATH"
                break
              fi
            done
          fi

          if [ ! -d "$LED_PATH" ]; then
            echo "No suitable LED path found, exiting"
            exit 1
          fi

          # Store original trigger
          ORIG_TRIGGER=$(cat "$LED_PATH/trigger" 2>/dev/null | grep -o '\[.*\]' | tr -d '[]' || echo "none")

          cleanup() {
            echo "Restoring LED to original state..."
            echo "$ORIG_TRIGGER" > "$LED_PATH/trigger" 2>/dev/null || \
              echo "chromeos-auto" > "$LED_PATH/trigger" 2>/dev/null || true
          }
          trap cleanup EXIT

          blink_on() {
            if [ -f "$LED_PATH/brightness" ]; then
              echo 255 > "$LED_PATH/brightness"
            fi
          }

          blink_off() {
            if [ -f "$LED_PATH/brightness" ]; then
              echo 0 > "$LED_PATH/brightness"
            fi
          }

          stop_blink() {
            rm -f /tmp/fingerprint-led.blinking
            # Restore original trigger, then set brightness so LED stays on
            echo "$ORIG_TRIGGER" > "$LED_PATH/trigger" 2>/dev/null || \
              echo "chromeos-auto" > "$LED_PATH/trigger" 2>/dev/null || true
            blink_on
          }

          # Background software blink loop - runs while /tmp/fingerprint-led.blinking exists
          software_blink_loop() {
            while [ -f /tmp/fingerprint-led.blinking ]; do
              blink_on
              ${lib.getExe' pkgs.busybox "usleep"} "${builtins.toString (cfg.blinkInterval * 1000)}"
              blink_off
              ${lib.getExe' pkgs.busybox "usleep"} "${builtins.toString (cfg.blinkInterval * 1000)}"
            done
          }

          start_blink() {
            # Use timer trigger if available for hardware blinking
            if grep -q "timer" "$LED_PATH/trigger" 2>/dev/null; then
              echo "timer" > "$LED_PATH/trigger"
              echo "$BLINK_INTERVAL" > "$LED_PATH/delay_on" 2>/dev/null || true
              echo "$BLINK_INTERVAL" > "$LED_PATH/delay_off" 2>/dev/null || true
            else
              # Fallback to software blinking
              echo "none" > "$LED_PATH/trigger" 2>/dev/null || true
              touch /tmp/fingerprint-led.blinking
              software_blink_loop &
            fi
          }

          BLINKING=false

          ${lib.getExe' pkgs.dbus "dbus-monitor"} --system "interface='net.reactivated.Fprint.Device'" | while IFS= read -r line; do
            case "$line" in
              *"member=VerifyFingerSelected"*)
                if [ "$BLINKING" != "true" ]; then
                  echo "Fingerprint waiting for touch, starting blink..."
                  BLINKING=true
                  start_blink
                fi
                ;;
              *"member=VerifyStatus"*)
                if [ "$BLINKING" = "true" ]; then
                  echo "Verify completed, stopping blink..."
                  BLINKING=false
                  stop_blink
                fi
                ;;
              *"member=Release"*|*"member=VerifyStop"*)
                if [ "$BLINKING" = "true" ]; then
                  echo "Fingerprint session ended, stopping blink..."
                  BLINKING=false
                  stop_blink
                fi
                ;;
            esac
          done
        '';
      };
    };
  };
}
