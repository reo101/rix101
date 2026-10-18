{ lib }:

let
  root = ./tests/packages;
  evaluated = lib.evalModules {
    specialArgs = {
      inherit lib;
      inputs = {
        marker = "inputs";
        nixpkgs = ./tests/fake-nixpkgs.nix;
        nix-enraged.packages = lib.genAttrs [ "x86_64-linux" "x86_64-darwin" ] (_: {
          default = "nix-enraged";
        });
      };
      self.outPath = toString root;
    };
    modules = [
      ../lib
      ../things
      ./default.nix
      {
        options.flake = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.unspecified;
          default = { };
        };
        options.flake-file = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.unspecified;
          default = { };
        };
        options.perSystem = lib.mkOption {
          type = lib.types.unspecified;
          default = { };
        };
        config.lib = {
          inherit (lib.custom)
            and
            eq
            recurseDir
            hasNixFiles
            kebabToCamel
            ;
        };
        config.auto.packages = {
          enable = true;
          dir = root;
        };
      }
    ];
  };
  configuration = evaluated.config;
  packages =
    system:
    (configuration.perSystem {
      pkgs = { };
      inherit system;
    }).legacyPackages;
  linux = packages "x86_64-linux";
  darwin = packages "x86_64-darwin";
in
{
  missingMetadataUsesDefaults = linux.absent == "absent";
  partialMetadataUsesCurriedDefault =
    linux.partial == "partial" && !configuration.auto.packages.result.partial.meta.curried;
  curriedPackageReceivesInputsAndLib = linux.curried == "inputs-curried";
  curriedDefaultsToFalseWithoutSignatureInference =
    !configuration.auto.packages.result.ordinary.meta.curried
    && builtins.isFunction configuration.auto.packages.result.ordinary.package;
  ordinaryFunctionIsDispatchedByCallPackage = linux.ordinary == "ordinary";
  systemsMetadataFiltersBeforePackageEvaluation = !(linux ? unsupported);
  systemsMetadataSelectsTargetSystem = linux.linux-only == "linux" && !(darwin ? linux-only);
  unrelatedLegacyPackageRemainsPresent = linux.nix-enraged == "nix-enraged";
}
