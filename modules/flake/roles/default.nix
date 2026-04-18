{
  lib,
  config,
  self,
  ...
}:

let
  inherit (lib) types;

  # Derive valid flavours from the registered configuration types
  # (i.e. the directory names under `hosts/`)
  flavours = builtins.attrNames config.auto.configurations.configurationTypes;

  # Per-flavour submodule: { modules, extraImports, extraConfig }
  # NOTE: field names avoid `imports` and `config` which are
  #       reserved by the module system inside submodule evaluation.
  flavourSubmodule = types.submodule {
    options = {
      modules = lib.mkOption {
        description = "Module names to pull from the flavour's module registry";
        type = types.listOf types.str;
        default = [ ];
      };
      extraImports = lib.mkOption {
        description = "Inline NixOS/HM/… modules to import directly";
        type = types.listOf types.deferredModule;
        default = [ ];
      };
      extraConfig = lib.mkOption {
        description = "Inline config attrset injected as a module";
        type = types.attrsOf types.anything;
        default = { };
      };
    };
  };

  # The full role schema used as the submodule type for the result
  # option — the module system validates structure automatically.
  roleType = types.submodule {
    options = {
      description = lib.mkOption {
        description = "Human-readable summary of what this role provides";
        type = types.str;
      };
      includes = lib.mkOption {
        description = "Other role names to transitively include";
        type = types.listOf types.str;
        default = [ ];
      };
    } // lib.genAttrs flavours (_: lib.mkOption {
      description = "Flavour-specific module selection";
      type = flavourSubmodule;
      default = { };
    });
  };
in
{
  key = "rix101.modules.flake.roles";

  imports = [
    ../lib
    ../things
    ../configurations
  ];

  options =
    let
      inherit (config.lib.custom)
        createThings
        ;

      createRoles =
        baseDir:
        createThings {
          inherit baseDir;
          recursive = true;
          raw = false;
          thingType = "role";
          extras = lib.genAttrs flavours (_: { default = { }; });
          handle = _name: result: lib.recursiveUpdate result.role (lib.removeAttrs result [ "role" ]);
        };
    in
    {
      auto.roles = lib.mkOption {
        description = ''
          Automagically generate host-composition roles from the `roles/` registry
        '';
        type = types.submodule (_: {
          options = {
            enable = lib.mkEnableOption "Automatic roles extraction";
            dir = lib.mkOption {
              description = ''
                Base directory of the contained roles
              '';
              type = types.path;
              default = "${self}/roles";
              defaultText = "\${self}/roles";
            };
            result = lib.mkOption {
              description = ''
                The resulting automatic roles
              '';
              type = types.attrsOf roleType;
              readOnly = true;
              internal = true;
              default = lib.optionalAttrs config.auto.roles.enable (createRoles config.auto.roles.dir);
            };
          };
        });
        default = { };
      };
    };

  config.flake.roles = config.auto.roles.result;
}
