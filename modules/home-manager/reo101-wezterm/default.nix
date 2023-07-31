{ lib, pkgs, config, ... }:

with lib;
let
  cfg = config.reo101.wezterm;
in
{
  imports =
    [
    ];

  options =
    {
      reo101.wezterm = {
        enable = mkEnableOption "reo101 wezterm setup";
        extraConfig = mkOption {
          type = types.str;
          description = "Extra wezterm config";
          default = ''
          '';
        };
      };
    };

  config =
    mkIf cfg.enable {
      home.packages = with pkgs;
        builtins.concatLists [
          [
            wezterm
            (nerdfonts.override { fonts = [ "FiraCode" ]; })
          ]
        ];

      programs.wezterm = {
        enable = true;
        extraConfig = builtins.concatStringsSep "\n" [
          (builtins.readFile ./wezterm.lua)
          cfg.extraConfig
        ];
      };
    };

  meta = {
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
