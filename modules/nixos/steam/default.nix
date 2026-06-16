{ lib, pkgs, config, ... }:

let
  cfg = config.rix101.steam.extest;
  inherit (lib)
    genAttrs
    mkEnableOption
    mkIf
    mkOption
    types
    ;
in
{
  options.rix101.steam.extest = {
    enable = mkEnableOption "Steam extest integration";

    package = mkOption {
      type = types.package;
      description = "extest package to preload into Steam.";
      default = pkgs.custom.extest;
      defaultText = "pkgs.custom.extest";
    };

    steamPackage = mkOption {
      type = types.package;
      description = "Steam package to wrap with extest.";
      default = pkgs.steam;
      defaultText = "pkgs.steam";
    };

    users = mkOption {
      type = types.listOf types.str;
      description = "Users allowed to create virtual input devices for extest.";
      default = [ ];
    };
  };

  config = mkIf cfg.enable {
    programs.steam = {
      extest.enable = true;
      package = lib.mkDefault (
        cfg.steamPackage.override (prev: {
          extraEnv = (prev.extraEnv or { }) // {
            LD_PRELOAD = "${cfg.package}/lib/libextest.so";

            # Steam Remote Play's PipeWire capturer uses `GBM`. On NixOS the `GBM`
            # backend lives under `/run/opengl-driver`, while `pressure-vessel`
            # usually looks for `/usr/lib/.../gbm/dri_gbm.so`, failing to find
            # it there and defaulting back to a black-frame stream
            GBM_BACKENDS_PATH = "/run/opengl-driver/lib/gbm";
          };

          # Required for Steam Remote Play desktop capture on Wayland
          # Without this Steam falls back to Desktop OpenGL capture and logs:
          # - ` WARNING: Desktop capture unavailable, try running Steam with -pipewire`
          extraArgs = lib.concatStringsSep " " [
            (prev.extraArgs or "")
            "-pipewire"
          ];

          # Steam's hardware updater is a bundled `PyInstaller` app that `dlopen()`s
          # `hidapi` by `soname`. Putting these in Steam's FHS environment lets
          # Steam's own `steam-runtime-launch-client` updater checks work without
          # relying on `LD_LIBRARY_PATH` being preserved
          extraLibraries =
            pkgs':
            (prev.extraLibraries or (_: [ ])) pkgs'
            ++ [
              pkgs'.hidapi
              pkgs'.libusb1
              pkgs'.mesa
              pkgs'.zlib
            ];
        })
      );
    };

    hardware.uinput.enable = true;

    users.users = genAttrs cfg.users (_: {
      extraGroups = [
        "input"
        "uinput"
      ];
    });
  };

  meta.maintainers = with lib.maintainers; [ reo101 ];
}
