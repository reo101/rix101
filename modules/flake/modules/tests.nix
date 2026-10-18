{ lib }:

let
  evaluate =
    overrides:
    (lib.evalModules {
      specialArgs = {
        inherit lib;
        inputs = { };
        self.outPath = ../../..;
      };
      modules = [
        ./default.nix
        {
          options.flake = lib.mkOption {
            type = lib.types.lazyAttrsOf lib.types.unspecified;
            default = { };
          };
          config = {
            lib = {
              inherit (lib.custom)
                and
                eq
                recurseDir
                hasNixFiles
                kebabToCamel
                ;
            };
            auto.modules = {
              enableAll = true;
              classes =
                lib.genAttrs
                  [
                    "nixos"
                    "nix-darwin"
                    "home-manager"
                    "nix-on-droid"
                    "flake"
                  ]
                  (_: {
                    dir = ../aspects/tests;
                  });
            };
          };
        }
        overrides
      ];
    }).config;
  defaultConfiguration = evaluate { };
  renamedConfiguration = evaluate {
    auto.modules.classes.home-manager.modulesName = {
      old = "userModules";
      new = "user";
    };
  };
  stringConfiguration = evaluate {
    auto.modules.classes.home-manager.modulesName = "userModules";
  };
  canonicalOnlyConfiguration = evaluate {
    auto.modules.classes.home-manager.modulesName = {
      old = null;
      new = "homeManager";
    };
  };
  legacyOnlyConfiguration = evaluate {
    auto.modules.classes.home-manager.modulesName = {
      old = "homeManagerModules";
      new = null;
    };
  };
  disabledConfiguration = evaluate {
    auto.modules.classes.home-manager.modulesName = {
      old = null;
      new = null;
    };
  };
  importedAliases = lib.evalModules {
    modules = [
      {
        options.test.shared = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
      }
      defaultConfiguration.flake.nixosModules.shared
      defaultConfiguration.flake.modules.nixos.shared
    ];
  };
in
{
  defaultLegacyModuleNames = builtins.all (name: defaultConfiguration.flake.${name} ? shared) [
    "nixosModules"
    "darwinModules"
    "homeManagerModules"
    "nixOnDroidModules"
    "flakeModules"
  ];
  defaultCanonicalModuleNames =
    builtins.all (class: defaultConfiguration.flake.modules.${class} ? shared)
      [
        "nixos"
        "darwin"
        "homeManager"
        "nixOnDroid"
        "flake"
      ];
  customModuleExportNames =
    renamedConfiguration.flake.userModules ? shared
    && renamedConfiguration.flake.modules.user ? shared
    && !(renamedConfiguration.flake ? homeManagerModules)
    && !(renamedConfiguration.flake.modules ? homeManager)
    && renamedConfiguration.auto.modules.result.homeManager ? shared;
  stringModuleNameSelectsLegacyOnly =
    stringConfiguration.flake.userModules ? shared
    && !(stringConfiguration.flake.modules ? homeManager);
  legacyModuleExportCanBeDisabled =
    !(canonicalOnlyConfiguration.flake ? homeManagerModules)
    && canonicalOnlyConfiguration.flake.modules.homeManager ? shared;
  canonicalModuleExportCanBeDisabled =
    legacyOnlyConfiguration.flake.homeManagerModules ? shared
    && !(legacyOnlyConfiguration.flake.modules ? homeManager);
  disabledModuleExportsRetainInternalRegistry =
    !(disabledConfiguration.flake ? homeManagerModules)
    && !(disabledConfiguration.flake.modules ? homeManager)
    && disabledConfiguration.auto.modules.result.homeManager ? shared;
  legacyAndCanonicalImportsRetainModuleIdentity = importedAliases.config.test.shared == [ "shared" ];
}
