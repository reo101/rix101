{ lib, config, self, inputs, ... }:

let
  inherit (config.lib)
    createThings
    configuration-type-to-outputs-modules;
in
let
  # Modules helpers
  moduleTypes = ["nixos" "nix-on-droid" "nix-darwin" "home-manager" "flake"];

  createModules = baseDir:
    createThings {
      inherit baseDir;
      thingType = "module";
    };
in
{
  options = let
    inherit (lib) types;
  in {
    flake.autoModules = lib.mkOption {
      description = ''
        Automagically generate modules from walking directories with Nix files
      '';
      type = types.submodule (submodule: {
        options = {
          enableAll = lib.mkEnableOption "Automatic ${builtins.toString moduleTypes} modules extraction";
          baseDir = lib.mkOption {
            description = ''
              Base directory of the contained modules, used as a base for the rest of the options
            '';
            type = types.path;
            default = "${self}/modules";
            defaultText = ''''${self}/modules'';
          };
        } // (
          lib.pipe
          moduleTypes
          [
            (builtins.map
              # NOTE: create small submodule for every `moduleType`
              (moduleType:
                lib.nameValuePair
                "${moduleType}"
                (lib.mkOption {
                  type = types.submodule {
                    options = {
                      # NOTE: each can be enabled (default global `enableAll`)
                      enable = lib.mkEnableOption "Automatic ${moduleType} modules extraction" // {
                        default = submodule.config.enableAll;
                      };
                      # NOTE: each can be read from a different directory
                      # (default global `baseDir` + `camelToKebab`-ed `moduleType`)
                      dir = lib.mkOption {
                        type = types.path;
                        default = "${submodule.config.baseDir}/${moduleType}";
                      };
                      result = lib.mkOption {
                        description = ''
                          The resulting automatic packages
                        '';
                        # TODO: specify
                        type = types.unspecified;
                        readOnly = true;
                        internal = true;
                        default =
                          lib.optionalAttrs
                            config.flake.autoModules.${moduleType}.enable
                            (createModules config.flake.autoModules.${moduleType}.dir);
                      };
                    };
                  };
                  default = {};
                })))
            builtins.listToAttrs
          ]);
      });
      default = {};
    };
  };

  config = {
    flake = let
      autoModules =
        lib.pipe
          moduleTypes
          [
            (builtins.map
              (moduleType:
                let
                  name = "${configuration-type-to-outputs-modules moduleType}";
                  value = config.flake.autoModules.${moduleType}.result;
                in
                  lib.nameValuePair name value))
            builtins.listToAttrs
          ];
    in autoModules;
  };
}
