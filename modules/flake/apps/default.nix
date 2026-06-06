{ lib, config, self, inputs, ... }:

{
  key = "rix101.modules.flake.apps";

  imports = [
    ../lib
    ../things
  ];

  options =
    let
      inherit (lib) types;
      inherit (config.lib.custom) createThings;

      createApps = baseDir:
        createThings {
          inherit baseDir;
          thingType = "app";
          raw = true;
          filter = name: type:
            # `apps/default.nix` is the legacy/manual apps entrypoint, not an app.
            name != "default.nix";
        };
    in
    {
      auto.apps = lib.mkOption {
        description = ''
          Automagically generate flake apps from Nix files/directories.
        '';
        type = types.submodule (_: {
          options = {
            enable = lib.mkEnableOption "Automatic apps extraction";
            dir = lib.mkOption {
              description = ''
                Base directory of the contained apps.
              '';
              type = types.path;
              default = "${self}/apps";
              defaultText = ''''${self}/apps'';
            };
            result = lib.mkOption {
              description = ''
                The resulting automatic apps before per-system evaluation.
              '';
              type = types.attrsOf types.unspecified;
              readOnly = true;
              internal = true;
              default =
                lib.optionalAttrs
                  config.auto.apps.enable
                  (createApps config.auto.apps.dir);
            };
          };
        });
        default = { };
      };
    };

  config = lib.mkIf config.auto.apps.enable {
    perSystem = perSystemArgs@{ pkgs, ... }:
      let
        passthru = perSystemArgs // {
          inherit inputs self;
          inherit (config) lib;
        };

        callApp = name: app:
          if builtins.isFunction app then
            app (lib.intersectAttrs (builtins.functionArgs app) passthru)
          else
            app;
      in
      {
        apps = lib.mapAttrs callApp config.auto.apps.result;
      };
  };
}
