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
    services= {
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

      # sketchybar = {
      #   enable = true;
      #   package = pkgs.sketchybar;
      # };
    };
  };

  meta = {
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
