{
  lib,
  config,
  self,
  ...
}:

{
  key = "rix101.modules.flake.roles";

  imports = [
    ../lib
    ../things
  ];

  options =
    let
      inherit (lib)
        types
        ;
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
          extras = {
            nixos.default = { };
            "nix-on-droid".default = { };
            "nix-darwin".default = { };
            "home-manager".default = { };
            openwrt.default = { };
          };
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
              type = types.attrsOf types.unspecified;
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
