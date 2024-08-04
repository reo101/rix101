{ lib, config, self, inputs, ... }:

let
  inherit (config.lib)
    createThings;
in
let
  createOverlays = baseDir:
    createThings {
      inherit baseDir;
      thingType = "overlay";
    };
in
{
  options = let
    inherit (lib) types;
  in {
    flake.autoOverlays = lib.mkOption {
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
                config.flake.autoOverlays.enable
                (createOverlays config.flake.autoOverlays.dir);
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
          config.flake.autoOverlays.result
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
