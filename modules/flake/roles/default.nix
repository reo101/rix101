{
  lib,
  config,
  self,
  ...
}:

let
  inherit (lib) types;

  flavours = builtins.attrNames config.auto.configurations.configurationTypes;

  roleType = types.addCheck (types.attrsOf (types.listOf types.str)) (
    role: lib.all (flavour: builtins.elem flavour flavours) (builtins.attrNames role)
  );

  createRoles =
    baseDir:
    config.lib.custom.createThings {
      inherit baseDir;
      recursive = true;
    };
in
{
  key = "rix101.modules.flake.roles";

  imports = [
    ../things
  ];

  options.auto.roles = lib.mkOption {
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

  config.flake.roles = config.auto.roles.result;
}
