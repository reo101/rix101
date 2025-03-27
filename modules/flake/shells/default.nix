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
      ;

    createDevShells = baseDir:
      createThings {
        inherit baseDir;
        thingType = "devShell";
        raw = false;
        extras.systems = {
          default = lib.const true;
        };
      };
  in {
    auto.devShells = lib.mkOption {
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
                config.auto.devShells.enable
                (createDevShells config.auto.devShells.dir);
          };
        };
      });
      default = {};
    };
  };

  config = {
    perSystem = { lib, pkgs, system, ... }@perSystemArgs: let
      # NOTE: flake's packages, done here to avoid infinite recursion
      pkgs' = pkgs.extend (final: prev: inputs.self.packages.${system});
      devShells =
        lib.pipe
          config.auto.devShells.result
          [
            (lib.filterAttrs
              (name: { devShell, systems }:
                pkgs'.callPackage systems { inherit inputs; }))
            (lib.mapAttrs
              (name: { devShell, systems }:
                pkgs'.callPackage devShell { inherit inputs; inherit (perSystemArgs) config; }))
          ];
    in {
      inherit devShells;
    };
  };
}
