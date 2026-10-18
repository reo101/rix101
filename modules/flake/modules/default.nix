{ inputs, self, lib, config, ... }:

{
  key = "rix101.modules.flake.modules";

  imports = [
    ../lib
    ../things
  ];

  options = let
    inherit (lib)
      types
      ;
    inherit (config.lib.custom)
      createThings
      kebabToCamel
      ;

    createModules = baseDir:
      createThings {
        inherit baseDir;
        thingType = "module";
        mkThing = { thingDir, type, ... }:
          if type == "directory" then "${thingDir}/default.nix" else thingDir;
      };
  in {
    auto.modules = lib.mkOption {
      description = ''
        Automagically generate modules from walking directories with Nix files
      '';
      type = types.submodule (autoModulesSubmodule: let
        inherit (autoModulesSubmodule.config)
          classes
          enableAll
          baseDir
          ;
      in {
        options = {
          enableAll = lib.mkEnableOption "Automatic ${builtins.toString classes} modules extraction";
          baseDir = lib.mkOption {
            description = ''
              Base directory of the contained modules, used as a base for the rest of the options
            '';
            type = types.path;
            default = "${self}/modules";
            defaultText = ''''${self}/modules'';
          };
          classes = lib.mkOption {
            # NOTE: default value set in the global `config` below, for visibility
            type = types.attrsOf (types.submodule (classSubmodule@{ name, ... }: let
              inherit (classSubmodule.config)
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
                class = lib.mkOption {
                  description = "Module class used for aspect composition";
                  type = types.str;
                  default = {
                    nix-darwin = "darwin";
                    home-manager = "homeManager";
                    nix-on-droid = "nixOnDroid";
                  }.${name} or name;
                };
                modulesName = lib.mkOption {
                  description = ''
                    Public module export names. A string selects only the legacy export.
                    Set `old` or `new` to `null` to disable that export.
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
                  default = {
                    old = if name == "nix-darwin" then "darwinModules" else "${kebabToCamel name}Modules";
                    new = classSubmodule.config.class;
                  };
                  apply = value: if builtins.isString value then { old = value; new = null; } else value;
                };
                resultModules = lib.mkOption {
                  description = ''
                    The resulting automatic modules
                  '';
                  type = types.attrsOf types.deferredModule;
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
            default = lib.concatMapAttrs
              (_className: classConfig: {
                ${classConfig.class} = classConfig.resultModules;
              })
              classes;
          };
        };
      });
      default = {};
    };
  };

  config = {
    auto.modules.classes = lib.mkOptionDefault {
      nixos = {};
      nix-on-droid = {};
      nix-darwin = {};
      home-manager = {};
      flake = {};
    };

    flake = let
      moduleExports = scheme: lib.concatMapAttrs
        (_className: classConfig:
          let name = classConfig.modulesName.${scheme};
          in lib.optionalAttrs (name != null) {
            ${name} = classConfig.resultModules;
          })
        config.auto.modules.classes;
    in moduleExports "old" // { modules = moduleExports "new"; };
  };
}
