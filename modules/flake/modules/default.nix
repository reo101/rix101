{ lib, config, self, inputs, ... }:

{
  imports = [
    ../lib
  ];

  options = let
    inherit (lib)
      types
      ;
    inherit (config.lib)
      createThings
      kebabToCamel
      ;

    createModules = baseDir:
      createThings {
        inherit baseDir;
        thingType = "module";
      };
  in {
    auto.modules = lib.mkOption {
      description = ''
        Automagically generate modules from walking directories with Nix files
      '';
      type = types.submodule (autoModulesSubmodule: let
        inherit (autoModulesSubmodule.config)
          moduleTypes
          enableAll
          baseDir
          ;
      in {
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
          moduleTypes = lib.mkOption {
            type = types.attrsOf (types.submodule (moduleTypeSubmodule@{ name, ... }: let
              inherit (moduleTypeSubmodule.config)
                enable
                dir
                ;
            in {
              options = {
                # NOTE: each can be enabled (default global `enableAll`)
                enable = lib.mkEnableOption "Automatic ${name} modules extraction" // {
                  default = enableAll;
                };
                # NOTE: each can be read from a different directory
                dir = lib.mkOption {
                  type = types.path;
                  default = "${baseDir}/${name}";
                };
                modulesName = lib.mkOption {
                  description = ''
                    Name of the `modules` output
                  '';
                  type = types.str;
                  default = "${kebabToCamel name}Modules";
                };
                resultModules = lib.mkOption {
                  description = ''
                    The resulting automatic packages
                  '';
                  # TODO: specify
                  type = types.unspecified;
                  readOnly = true;
                  internal = true;
                  default =
                    lib.optionalAttrs
                      enable
                      (createModules dir);
                };
              };
            }));
            # TODO: put in a more visible place
            default = {
              nixos = {};
              nix-on-droid = {};
              nix-darwin = {
                modulesName = "darwinModules";
              };
              home-manager = {};
              flake = {};
            };
          };
          resultModules = lib.mkOption {
            readOnly = true;
            default = lib.pipe moduleTypes [
              (lib.mapAttrs'
                (moduleType: moduleTypeConfig:
                  lib.nameValuePair
                    moduleTypeConfig.modulesName
                    (lib.mapAttrs
                      (host: module:
                        module)
                      moduleTypeConfig.resultModules)))
            ];
          };
        };
      });
      default = {};
    };
  };

  config = {
    flake = let
      autoModules = config.auto.modules.resultModules;
    in autoModules;
  };
}
