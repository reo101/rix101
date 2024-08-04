{ lib, config, self, inputs, ... }:

let
  inherit (config.lib)
    createThings;
in
let
  createDevShells = baseDir:
    createThings {
      inherit baseDir;
      thingType = "devShell";
      raw = false;
      extras.systems = {
        default = lib.const true;
      };
    };
in
{
  options = let
    inherit (lib) types;
  in {
    flake.autoDevShells = lib.mkOption {
      description = ''
        Automagically generate devShells from walking directories with Nix files
      '';
      type = types.submodule (submodule: {
        options = {
          enable = lib.mkEnableOption "Automatic devShells extraction";
          dir = lib.mkOption {
            description = ''
              Base directory of the contained devShells
            '';
            type = types.path;
            default = "${self}/shells";
            defaultText = ''''${self}/shells'';
          };
          result = lib.mkOption {
            description = ''
              The resulting automatic devShells
            '';
            type = types.attrsOf (types.submodule { options = {
              devShell = lib.mkOption { type = types.unspecified; };
              systems = lib.mkOption { type = types.functionTo types.bool; };
            };});
            readOnly = true;
            internal = true;
            default =
              lib.optionalAttrs
                config.flake.autoDevShells.enable
                (createDevShells config.flake.autoDevShells.dir);
          };
        };
      });
      default = {};
    };
  };

  config = {
    perSystem = { lib, pkgs, system, ... }: let
      devShells =
        lib.pipe
          config.flake.autoDevShells.result
          [
            (lib.filterAttrs
              (name: { devShell, systems }:
                pkgs.callPackage systems {
                  inherit (pkgs) lib hostPlatform targetPlatform;
                }))
            (lib.mapAttrs
              (name: { devShell, systems }:
                pkgs.callPackage devShell { inherit inputs; }))
          ];
    in {
      inherit devShells;
    };
  };
}
