{
  inputs,
  lib,
  pkgs,
  config,
  osConfig ? null,
  ...
}:

let
  niriSettings =
    {
      onBattery ? false,
    }:
    import ./settings.nix {
      inherit
        config
        lib
        pkgs
        osConfig
        niriFloatSticky
        onBattery
        ;
    };

  batteryNiriSettings = inputs.niri.lib.settings.eval-settings {
    inherit lib pkgs;
    settings = niriSettings { onBattery = true; };
  };
  batteryNiriConfigFile = batteryNiriSettings.config.validated {
    package = config.programs.niri.package;
  };

  niriPowerSourceSync = pkgs.writeShellApplication {
    name = "niri-power-source-sync";
    runtimeInputs = [
      config.programs.niri.package
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      set -eu

      state_dir="$XDG_RUNTIME_DIR/niri"
      state_file="$state_dir/power-source-config"
      base_config="${config.xdg.configHome}/niri/config.kdl"
      battery_config="${config.xdg.configHome}/niri/config-battery.kdl"
      on_battery="$(busctl --system get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower OnBattery 2>/dev/null || true)"

      case "$on_battery" in
        "b true")
          target_config="$battery_config"
          ;;
        "b false")
          target_config="$base_config"
          ;;
        *)
          exit 0
          ;;
      esac

      if [ ! -r "$target_config" ]; then
        exit 0
      fi

      mkdir -p "$state_dir"

      if [ -r "$state_file" ] && [ "$(cat "$state_file")" = "$target_config" ]; then
        exit 0
      fi

      ${lib.getExe config.programs.niri.package} msg action load-config-file --path "$target_config"
      printf '%s\n' "$target_config" > "$state_file"
    '';
  };

  niriPowerSourceMonitor = pkgs.writeShellApplication {
    name = "niri-power-source-monitor";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.upower
      niriPowerSourceSync
    ];
    text = ''
      set -eu

      stdbuf -oL -eL upower --monitor | while IFS= read -r _line; do
        niri-power-source-sync || true
      done
    '';
  };

  niriFloatSticky = pkgs.writeShellApplication {
    name = "niri-float-sticky-start";
    runtimeInputs = [
      config.programs.niri.package
      pkgs.custom.niri-float-sticky
    ];
    text = ''
      exec niri-float-sticky
    '';
  };
in
{
  imports = [
    inputs.niri.homeModules.niri
    ./noctalia.nix
  ];

  home.packages = [
    pkgs.xwayland-satellite
  ];

  xdg.configFile.niri-battery-config = {
    enable = config.programs.niri.finalConfig != null;
    target = "niri/config-battery.kdl";
    source = batteryNiriConfigFile;
  };

  systemd.user.services.niri-power-source-sync = {
    Unit = {
      Description = "Sync Niri power-saving visuals with current power source";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe niriPowerSourceSync;
    };
  };

  systemd.user.services.niri-power-source-monitor = {
    Unit = {
      Description = "Watch UPower for Niri power-saving overrides";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStartPre = lib.getExe niriPowerSourceSync;
      ExecStart = lib.getExe niriPowerSourceMonitor;
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  programs.niri = {
    enable = true;
    package = (inputs.niri.lib.internal.make-package-set pkgs).niri-unstable;
    # package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable.overrideAttrs (oldAttrs: let
    #   src = pkgs.fetchFromGitHub {
    #     owner = "niri-wm";
    #     repo = "niri";
    #     rev = "4c4863a29cbec643e24f211b111a8de98c980136";
    #     hash = "sha256-dGRgX8apemRre1Za/p00ZhUiCjQqy9h0HHEgA96ZkYs=";
    #   };
    # in {
    #   inherit src;
    #   version = "unstable-blur";
    #   cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
    #     inherit src;
    #     hash = "sha256-soJYT6TavlyqtVqMD70QYDZ+8swn6TVXsFHadJxaxWo=";
    #   };
    # });
    settings = niriSettings { };
  };
}
