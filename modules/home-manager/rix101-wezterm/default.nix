{
  lib,
  pkgs,
  config,
  ...
}:

with lib;
let
  cfg = config.rix101.wezterm;
in
{
  imports = [
  ];

  options = {
    rix101.wezterm = {
      enable = mkEnableOption "rix101 wezterm setup";
      extraConfig = mkOption {
        type = types.str;
        description = "Extra wezterm config";
        default = "";
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      lib.concatLists [
        [
          wezterm
          nerd-fonts.fira-code
        ]
      ];

    programs.wezterm = {
      enable = true;
      extraConfig = lib.concatStringsSep "\n" [
        (builtins.readFile ./wezterm.lua)
        cfg.extraConfig
      ];
    };
  };

  meta = {
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
