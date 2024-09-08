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

  config = mkIf cfg.enable (
    let
      borders = pkgs.callPackage ./borders { };
      setbg = pkgs.callPackage ./setbg {
        yabai = config.services.yabai.package;
      };
    in
    {
      environment.systemPackages = [
        borders
        setbg
      ];

      services = {
        yabai = {
          enable = true;
          package = pkgs.yabai;
          enableScriptingAddition = true;
          extraConfig = /* bash */ ''
            ${builtins.readFile ./yabairc}

            # Load JankyBorders
            ${borders}/bin/borders active_color=0xffe1e3e4 inactive_color=0xff494d64 style=squared width=5.0 &
          '';
        };

        skhd = {
          enable = true;
          package = pkgs.skhd;
          skhdConfig = builtins.readFile ./skhdrc;
        };

        # sketchybar = {
        #   enable = true;
        #   package = pkgs.sketchybar;
        #   extraPackages = with pkgs; [
        #     jq
        #   ];
        #   config = import (lib.getExe (pkgs.callPackage ./sketchybar { }));
        # };
      };

      # TODO: make builtin module work with scripts
      launchd.user.agents.sketchybar = let
        cfg = rec {
          package = pkgs.sketchybar;
          extraPackages = with pkgs; [
            jq
          ];
          configFile = lib.getExe (pkgs.callPackage ./sketchybar { sketchybar = package; });
        };
      in {
        path = [ cfg.package ] ++ cfg.extraPackages ++ [ config.environment.systemPath ];
        serviceConfig.ProgramArguments =
          [
            "${lib.getExe cfg.package}"
          ] ++ optionals (cfg.configFile != null) [
            "--config"
            "${cfg.configFile}"
          ];
        serviceConfig.KeepAlive = true;
        serviceConfig.RunAtLoad = true;
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
    });

  meta = {
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
