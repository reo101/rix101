# Non-module dependencies (`importApply`)
{ }:

# Service module
{
  lib,
  config,
  options,
  ...
}:
let
  inherit (lib) types;
  cfg = config.osu-touchpad;
  screenAreaUsed =
    cfg.screenArea.xMin != null
    || cfg.screenArea.xMax != null
    || cfg.screenArea.yMin != null
    || cfg.screenArea.yMax != null;

  cliArgs =
    [ "--device" cfg.device ]
    ++ lib.optionals (cfg.watchProcess != null) [
      "--watch"
      cfg.watchProcess
    ]
    ++ lib.optionals (cfg.activeArea.xMin != null) [
      "--x-min"
      (toString cfg.activeArea.xMin)
    ]
    ++ lib.optionals (cfg.activeArea.xMax != null) [
      "--x-max"
      (toString cfg.activeArea.xMax)
    ]
    ++ lib.optionals (cfg.activeArea.yMin != null) [
      "--y-min"
      (toString cfg.activeArea.yMin)
    ]
    ++ lib.optionals (cfg.activeArea.yMax != null) [
      "--y-max"
      (toString cfg.activeArea.yMax)
    ]
    ++ lib.optionals (cfg.activeArea.aspectRatio != null) [
      "--aspect"
      cfg.activeArea.aspectRatio
    ]
    ++ lib.optionals (cfg.screenWidth != null) [
      "--screen-width"
      (toString cfg.screenWidth)
    ]
    ++ lib.optionals (cfg.screenHeight != null) [
      "--screen-height"
      (toString cfg.screenHeight)
    ]
    ++ lib.optionals (cfg.screenArea.xMin != null) [
      "--screen-x-min"
      (toString cfg.screenArea.xMin)
    ]
    ++ lib.optionals (cfg.screenArea.xMax != null) [
      "--screen-x-max"
      (toString cfg.screenArea.xMax)
    ]
    ++ lib.optionals (cfg.screenArea.yMin != null) [
      "--screen-y-min"
      (toString cfg.screenArea.yMin)
    ]
    ++ lib.optionals (cfg.screenArea.yMax != null) [
      "--screen-y-max"
      (toString cfg.screenArea.yMax)
    ]
    ++ lib.optionals (cfg.focusMatch != null) [
      "--focus-match"
      cfg.focusMatch
      "--focus-query"
      cfg.focusQuery
    ]
    ++ [
      "--output-width"
      (toString cfg.outputWidth)
      "--output-height"
      (toString cfg.outputHeight)
    ]
    ++ lib.optional (!cfg.clickOnTouch) "--no-click-on-touch"
    ++ lib.optional cfg.debug "--debug"
    ++ cfg.extraArgs;
in
{
  _class = "service";

  options.osu-touchpad = {
    package = lib.mkOption {
      type = types.package;
      description = "osu-touchpad package to run.";
      defaultText = "The osu-touchpad package that provided this module.";
    };

    watchProcess = lib.mkOption {
      type = types.nullOr types.str;
      default = "osu!";
      description = ''
        Engage tablet mode only while some process's `/proc/<pid>/cmdline`
        contains this substring (own pid excluded). The service then idles
        cheaply and grabs/releases the touchpad as the process appears and
        disappears.

        Set to `null` for manual control only: the mapper is active exactly
        between `systemctl start` and `systemctl stop`, and the unit is not
        pulled in by any target.
      '';
      example = "osu!lazer";
    };

    device = lib.mkOption {
      type = types.str;
      default = "PIXA3854:00 093A:0274 Touchpad";
      description = ''
        Physical touchpad: an exact evdev device name to scan
        `/dev/input/event*` for (robust against renumbering), or an absolute
        device path.
      '';
    };

    activeArea = lib.mkOption {
      type = types.submodule {
        options = {
          xMin = lib.mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Physical crop lower X bound. `null` uses the device absinfo minimum (full surface).";
          };
          xMax = lib.mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Physical crop upper X bound. `null` uses the device absinfo maximum (full surface).";
          };
          yMin = lib.mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Physical crop lower Y bound. `null` uses the device absinfo minimum (full surface).";
          };
          yMax = lib.mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Physical crop upper Y bound. `null` uses the device absinfo maximum (full surface).";
          };
          aspectRatio = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "16:9";
            description = ''
              Center-crop the active area to this `W:H` ratio so finger
              motion is not stretched. `null` imposes no crop (the Framework
              16 pad is ~1.61:1, close to 16:10).
            '';
          };
        };
      };
      default = { };
      description = "Absolute area of the touchpad mapped to the full output.";
    };

    screenArea = lib.mkOption {
      type = types.submodule {
        options = {
          xMin = lib.mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Screen box left edge in logical pixels.";
          };
          xMax = lib.mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Screen box right edge in logical pixels.";
          };
          yMin = lib.mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Screen box top edge in logical pixels.";
          };
          yMax = lib.mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Screen box bottom edge in logical pixels.";
          };
        };
      };
      default = { };
      description = ''
        Logical-pixel box of the output the pad area is mapped onto, the
        screen half of the coordinate pair (pad half is `activeArea`).
        Expressed in the compositor's logical coordinates (after scale;
        the Framework panel is 2048x1280 at scale 1.25). Any field left
        null defaults to the output edge. Requires `screenWidth` and
        `screenHeight`; with the box unset entirely the pad area stretches
        across the whole output.
      '';
      default = { };
    };

    screenWidth = lib.mkOption {
      type = types.nullOr types.int;
      default = null;
      description = ''
        Logical width of the output, needed to place `screenArea`
        (e.g. 2048 for the 2560x1600 panel at scale 1.25).
      '';
    };

    screenHeight = lib.mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Logical height of the output (e.g. 1280 at scale 1.25).";
    };

    focusMatch = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "osu";
      description = ''
        Engage tablet mode only while the output of `focusQuery` contains
        this substring (niri's focused window title / app id). Switching
        away from the window releases the touchpad immediately. When the
        query command fails, the service falls back to `watchProcess`.
      '';
    };

    focusQuery = lib.mkOption {
      type = types.str;
      default = "niri msg focused-window";
      description = ''
        Shell command returning the focused-window information that
        `focusMatch` is matched against.
      '';
    };

    outputWidth = lib.mkOption {
      type = types.ints.positive;
      default = 32767;
      description = "Maximum of the virtual `ABS_X` axis (range `0..outputWidth`).";
    };

    outputHeight = lib.mkOption {
      type = types.ints.positive;
      default = 32767;
      description = "Maximum of the virtual `ABS_Y` axis (range `0..outputHeight`).";
    };

    clickOnTouch = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Emit `BTN_LEFT` while the primary finger contacts the pad (tablet pen-down semantics).";
    };

    debug = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Log finger down/up and raw/mapped coordinates to the journal.";
    };

    extraArgs = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra raw command-line arguments passed to the mapper.";
    };
  };

  config = {
    meta.maintainers = with lib.maintainers; [ reo101 ];

    assertions = [
      {
        assertion = !screenAreaUsed || (cfg.screenWidth != null && cfg.screenHeight != null);
        message = "osu-touchpad: screenArea requires screenWidth and screenHeight to be set";
      }
    ];

    process.argv = [ (lib.getExe cfg.package) ] ++ cliArgs;
  }
  // lib.optionalAttrs (options ? systemd) {
    systemd.service = {
      wantedBy = lib.optional (cfg.watchProcess != null) "default.target";
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 2;

        # The user must have `input`/`uinput` access to these devices.
        # PrivateDevices would hide /dev/input/event* and /dev/uinput.
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateUsers = false;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [ "AF_UNIX" ];
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
      };
    };
  };
}
