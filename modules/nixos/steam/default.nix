{
  config,
  lib,
  pkgs,
  ...
}:

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
      default = pkgs.custom.extest;
      defaultText = "pkgs.custom.extest";
      description = "extest package to preload into Steam.";
    };

    users = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Users allowed to create virtual input devices for extest.";
    };
  };

  config = mkIf cfg.enable {
    programs.steam = {
      extest.enable = true;
      package = lib.mkDefault (
        pkgs.steam.override (prev: {
          extraEnv = (prev.extraEnv or { }) // {
            LD_PRELOAD = "${cfg.package}/lib/libextest.so";
          };
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
