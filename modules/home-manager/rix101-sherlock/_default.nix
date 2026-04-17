{ inputs, meta, lib, pkgs, config, ... }:

let
  cfg = config.reo101.sherlock;
in
{
  # import the sherlock homeManager Module
  imports = [
    inputs.sherlock.homeManagerModules.default
  ];

  options =
    {
      reo101.sherlock = {
        enable = lib.mkEnableOption "reo101 sherlock setup";
      };
    };

  config = lib.mkIf cfg.enable {
    programs.sherlock = {
      enable = true;

      # for faster startup times
      runAsService = true;

      settings = {
        # config.json / config.toml
        # use nix syntax
        config = {};

        # fallback.json
        # A list of launchers
        launchers = [
          {
            name = "Calculator";
            type = "calculation";
            args = {
              capabilities = [
                "calc.math"
                "calc.units"
              ];
            };
            priority = 1;
          }
          {
            name = "App Launcher";
            type = "app_launcher";
            args = {};
            priority = 2;
            home = "Home";
          }
        ];

        # sherlock_alias.json
        # use nix syntax
        aliases = {
          legcord = { name = "Discord"; };
        };

        # main.css
        style = /* css */ ''
          * {
            font-family: sans-serif;
          }
        '';

        # sherlockignore
        ignore = ''
          Avahi*
        '';
      };
    };
  };
}
