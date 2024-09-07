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
      ;

    createOverlays = baseDir:
      createThings {
        inherit baseDir;
        thingType = "overlay";
      };
  in {
    auto.overlays = lib.mkOption {
      description = ''
        Automagically generate overlays from walking directories with Nix files
      '';
      type = types.submodule (submodule: {
        options = {
          enable = lib.mkEnableOption "Automatic overlays extraction";
          dir = lib.mkOption {
            description = ''
              Base directory of the contained overlays
            '';
            type = types.path;
            default = "${self}/overlays";
            defaultText = ''''${self}/overlays'';
          };
          result = lib.mkOption {
            description = ''
              The resulting automatic overlays
            '';
            type = types.attrsOf types.unspecified;
            readOnly = true;
            internal = true;
            default =
              lib.optionalAttrs
                config.auto.overlays.enable
                (createOverlays config.auto.overlays.dir);
          };
        };
      });
      default = {};
    };
  };

  config = {
    flake = let
      overlays =
        lib.pipe
          config.auto.overlays.result
          [
            (lib.mapAttrs
              (name: overlay:
                overlay))
          ];
    in {
      inherit overlays;
    };
  };
}
