{ lib, config, self, inputs, ... }:

{
  imports = [
    ../lib
    ../things
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
            # NOTE: default value set in the global `config` below, for visibility
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
                    Name(s) for the modules output.
                    Can be a string (used as `old`, with `new = null`) or an attrset with `old` and/or `new`.
                    - `old`: Name for the `''${moduleType}Modules` output (null to skip)
                    - `new`: Name for the `modules.''${moduleType}` output (null to skip)
                  '';
                  type = types.either types.str (types.submodule {
                    options = {
                      old = lib.mkOption {
                        type = types.nullOr types.str;
                        default = null;
                      };
                      new = lib.mkOption {
                        type = types.nullOr types.str;
                        default = null;
                      };
                    };
                  });
                  default = { old = "${kebabToCamel name}Modules"; new = name; };
                  apply = v: if builtins.isString v then { old = v; new = null; } else v;
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
          };
          result = lib.mkOption {
            readOnly = true;
            default = {
              modules = let
                mkResultModules = new: lib.pipe moduleTypes ([
                  (lib.concatMapAttrs
                    (_moduleType: moduleTypeConfig:
                      let name = moduleTypeConfig.modulesName.${if new then "new" else "old"};
                      in lib.optionalAttrs (name != null) {
                        ${name} =
                          lib.mapAttrs
                            (_host: module: module)
                            moduleTypeConfig.resultModules;
                      }))
                ] ++ lib.optional new (modules: { inherit modules; }));
              in {
                # NOTE: old:  ${name}Modules.${module}
                #       new: modules.${name}.${module}
                old = mkResultModules false;
                new = mkResultModules true;
              };
            };
          };
        };
      });
      default = {};
    };
  };

  config = {
    auto.modules.moduleTypes = lib.mkOptionDefault {
      nixos = {};
      nix-on-droid = {};
      nix-darwin = {
        modulesName = { old = "darwinModules"; new = "darwin"; };
      };
      home-manager = {};
      flake = {};
    };

    flake = let
      modulesOld = config.auto.modules.result.modules.old;
      modulesNew = config.auto.modules.result.modules.new;
    in modulesOld // modulesNew;
  };
}
