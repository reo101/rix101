{ config, pkgs, lib, ... }:
let
  inherit (lib)
    types
    mkOption
    mkEnableOption
    mkIf
    optional
    ;
  cfg = config.services.batteryNotify;
  battery-notify = pkgs.callPackage ./battery-notify.nix { };
in
{
  options.services.batteryNotify = {
    enable = mkEnableOption "Battery notification service";

    batteryName = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Battery device name (e.g., BAT0). If null, auto-detection will be used.";
      example = "BAT0";
    };

    thresholds = mkOption {
      description = "thresholds for battery levels";
      type = types.submodule {
        options = {
          critical = mkOption {
            type = types.int;
            default = 10;
            description = "Battery percentage threshold for critical notifications.";
          };

          low = mkOption {
            type = types.int;
            default = 20;
            description = "Battery percentage threshold for low notifications.";
          };

          mid = mkOption {
            type = types.int;
            default = 40;
            description = "Battery percentage threshold for medium notifications.";
          };
        };
      };
      default = {};
    };

    criticalTimeout = mkOption {
      type = types.int;
      default = 30;
      description = "Timeout in seconds to wait for charging after critical notification.";
    };

    # Timer settings as a submodule
    timer = mkOption {
      description = "Timer settings for battery checks";
      type = types.submodule {
        options = {
          checkIntervalMinutes = mkOption {
            type = types.int;
            default = 5;
            description = "How often to check battery status (in minutes).";
            example = 3;
          };

          initialDelaySeconds = mkOption {
            type = types.int;
            default = 60;
            description = "Delay after boot before first check (in seconds).";
            example = 30;
          };
        };
      };
      default = {};
    };
  };

  config = mkIf cfg.enable {
    # Assertion to ensure critical timeout doesn't overlap with timer interval
    assertions = [
      {
        assertion = cfg.criticalTimeout < (cfg.timer.checkIntervalMinutes * 60);
        message = ''
          Battery notification critical timeout (${toString cfg.criticalTimeout}s) must be less than check interval
          (${toString cfg.timer.checkIntervalMinutes} minutes = ${toString (cfg.timer.checkIntervalMinutes * 60)}s)
          to prevent overlapping service executions.
        '';
      }
      {
        assertion = cfg.thresholds.critical <= cfg.thresholds.low && cfg.thresholds.low <= cfg.thresholds.mid;
        message = ''
          Battery thresholds must be in non-decreasing order:
          critical (${toString cfg.thresholds.critical}) <= low (${toString cfg.thresholds.low}) <= mid (${toString cfg.thresholds.mid}).
        '';
      }
    ];

    systemd.user.services.battery-notify = {
      unitConfig = {
        Description = "Battery level notifier";
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe battery-notify;
        Environment = [
          "BATTERY_CRITICAL=${toString cfg.thresholds.critical}"
          "BATTERY_LOW=${toString cfg.thresholds.low}"
          "BATTERY_MID=${toString cfg.thresholds.mid}"
          "BATTERY_TIMEOUT=${toString cfg.criticalTimeout}"
        ] ++ (optional (cfg.batteryName != null) "BATTERY=${cfg.batteryName}");
      };
    };

    systemd.user.timers.battery-notify = {
      unitConfig = {
        Description = "Run battery-notify periodically";
      };
      timerConfig = {
        OnBootSec = "${toString cfg.timer.initialDelaySeconds}s";
        OnUnitActiveSec = "${toString cfg.timer.checkIntervalMinutes}m";
        Unit = "battery-notify.service";
      };
      wantedBy = [
        "default.target"
      ];
    };
  };
}
