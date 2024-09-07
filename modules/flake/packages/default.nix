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

    createPackages = baseDir:
      createThings {
        inherit baseDir;
        thingType = "package";
        raw = false;
        extras.systems = {
          default = lib.const true;
        };
      };
  in {
    auto.packages = lib.mkOption {
      description = ''
        Automagically generate packages from walking directories with Nix files
      '';
      type = types.submodule (submodule: {
        options = {
          enable = lib.mkEnableOption "Automatic packages extraction";
          dir = lib.mkOption {
            description = ''
              Base directory of the contained packages
            '';
            type = types.path;
            default = "${self}/pkgs";
            defaultText = ''''${self}/pkgs'';
          };
          result = lib.mkOption {
            description = ''
              The resulting automatic packages
            '';
            type = types.attrsOf (types.submodule { options = {
              package = lib.mkOption { type = types.unspecified; };
              systems = lib.mkOption { type = types.functionTo types.bool; };
            };});
            readOnly = true;
            internal = true;
            default =
              lib.optionalAttrs
                config.auto.packages.enable
                (createPackages config.auto.packages.dir);
          };
        };
      });
      default = {};
    };
  };

  config = {
    perSystem = { lib, pkgs, system, ... }: let
      packages =
        lib.pipe
          config.auto.packages.result
          [
            (lib.filterAttrs
              (name: { package, systems }:
                pkgs.callPackage systems {
                  inherit (pkgs) lib hostPlatform targetPlatform;
                }))
            (lib.mapAttrs
              (name: { package, systems }:
                let
                  # TODO: put in `autoThings` `handle`?
                  isDream2Nix = lib.pipe package
                    [
                      builtins.functionArgs
                      builtins.attrNames
                      (builtins.elem "dream2nix")
                    ];
                in
                  if isDream2Nix
                  then inputs.dream2nix.lib.evalModules {
                    packageSets.nixpkgs = pkgs;
                    modules = [
                      package
                      {
                        paths.projectRoot = "${self.outPath}";
                        paths.projectRootFile = "flake.nix";
                        paths.package = "${self.outPath}";
                      }
                    ];
                    specialArgs = {
                      # NOTE: for overlayed `maintainers`
                      inherit (pkgs) lib;
                    };
                  }
                else pkgs.callPackage package { }))
          ];
    in {
      inherit packages;
    };
  };
}
