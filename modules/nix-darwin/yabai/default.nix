{ lib, pkgs, config, ... }:

with lib;
let
  cfg = config.reo101.yabai;
in
{
  imports = [
  ];

  options = {
    reo101.yabai = {
      enable = mkEnableOption "reo101 yabai config";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.callPackage ./setbg {
        yabai = config.services.yabai.package;
      })
    ];

    services = {
      yabai = {
        enable = true;
        package = pkgs.yabai;
        enableScriptingAddition = true;
        extraConfig = (builtins.readFile ./yabairc);
      };

      skhd = {
        enable = true;
        package = pkgs.skhd;
        skhdConfig = (builtins.readFile ./skhdrc);
      };

      sketchybar = {
        enable = true;
        package = pkgs.sketchybar;
        extraPackages = with pkgs; [
          jq
        ];
        config = import ./sketchybar pkgs;
      };
    };

    # For sketchybar
    homebrew = {
      taps = [
        "shaunsingh/SFMono-Nerd-Font-Ligaturized"
      ];
      casks = [
        "font-sf-mono-nerd-font-ligaturized"
      ];
    };
  };

  meta = {
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
