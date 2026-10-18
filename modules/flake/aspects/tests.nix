{ lib, aspectLibrary }:

let
  composition = import ./bindings.nix { inherit lib aspectLibrary; };
  listOption = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
  };
  baseModule = {
    options.test = {
      values = listOption;
      shared = listOption;
      inline = listOption;
    };
  };
  evaluate =
    class: aspects:
    lib.evalModules {
      inherit class;
      modules = [
        baseModule
        (composition.resolveModules class aspects)
      ];
    };
  transitive = rec {
    leaf.nixos.test.values = [ "leaf" ];
    middle.includes = [ leaf ];
    middle.nixos.test.values = [ "middle" ];
    root.includes = [ middle ];
  };
  diamond = rec {
    shared.nixos.imports = [ ./tests/shared.nix ];
    left.includes = [ shared ];
    right.includes = [ shared ];
    root.includes = [
      left
      right
    ];
  };
  inlineProvider = {
    nixos.test.inline = [ "anonymous" ];
  };
  inlineDuplicate = evaluate "nixos" [
    inlineProvider
    inlineProvider
  ];
  includeOnly = evaluate "nixos" [ { includes = [ { nixos.test.values = [ "included" ]; } ]; } ];
  selected = evaluate "nixos" [
    {
      nixos.test.values = [ "nixos" ];
      homeManager.test.values = [ "home-manager" ];
      darwin.test.values = [ "darwin" ];
    }
  ];
  parameter = value: { nixos.test.values = [ value ]; };
  homeOptions = {
    options.home-manager.users = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            homeValues = listOption;
            hostOnly = listOption;
          };
        }
      );
    };
    options.hostOnly = listOption;
    options.test.values = listOption;
  };
  evaluateHost =
    arguments:
    lib.evalModules {
      class = "nixos";
      modules = [
        homeOptions
        (composition.resolveHost arguments)
      ];
    };
  hostMeta = {
    aspects = [
      {
        nixos.test.values = [ "host" ];
        homeManager.hostOnly = [ "host-only" ];
      }
    ];
    users = {
      alice.aspects = [
        {
          nixos.test.values = [ "alice-system" ];
          homeManager.homeValues = [ "alice" ];
        }
      ];
      bob.aspects = [
        {
          nixos.test.values = [ "bob-system" ];
          homeManager.homeValues = [ "bob" ];
        }
      ];
    };
  };
  host = evaluateHost {
    class = "nixos";
    meta = hostMeta;
    userNames = [
      "alice"
      "bob"
    ];
  };
  unselectedUser = lib.evalModules {
    class = "nixos";
    modules = [
      homeOptions
      { home-manager.users.carol = { }; }
      (composition.resolveHost {
        class = "nixos";
        meta = hostMeta;
        userNames = [
          "alice"
          "bob"
          "carol"
        ];
      })
    ];
  };
  unknownUser = builtins.tryEval (
    builtins.deepSeq
      (evaluateHost {
        class = "nixos";
        meta = hostMeta;
        userNames = [ "alice" ];
      }).config
      true
  );
  droid = lib.evalModules {
    class = "nixOnDroid";
    modules = [
      {
        options.home-manager.config = lib.mkOption {
          default = { };
          type = lib.types.submodule { options.homeValues = listOption; };
        };
      }
      (composition.resolveHost {
        class = "nixOnDroid";
        meta = {
          aspects = [ ];
          users.alice.aspects = [
            {
              homeManager.homeValues = [ "droid-home" ];
            }
          ];
        };
        userNames = [ "alice" ];
        homePath = _: [
          "home-manager"
          "config"
        ];
      })
    ];
  };
  typedAspects =
    (lib.evalModules {
      modules = [
        (aspectLibrary.new-scope "composition")
        {
          composition.aspects.profile = {
            nixos.test.values = [ "typed-system" ];
            homeManager.homeValues = [ "typed-home" ];
          };
        }
      ];
    }).config.composition.aspects;
  metadata =
    (lib.evalModules {
      specialArgs = {
        configurationType = "nixos";
        inputs.flake-aspects.lib = _: aspectLibrary;
        aspects = typedAspects;
      };
      modules = [
        ../configurations/meta-modules/aspects.nix
        ({ aspects, ... }: { users.operator.aspects = [ aspects.profile ]; })
      ];
    }).config;
  typedHost = evaluateHost {
    class = "nixos";
    meta = metadata;
    userNames = [ "operator" ];
  };
  standaloneMetadata =
    (lib.evalModules {
      specialArgs = {
        configurationType = "home-manager";
        inputs.flake-aspects.lib = _: aspectLibrary;
        aspects = typedAspects;
      };
      modules = [
        ../configurations/meta-modules/aspects.nix
        ({ aspects, ... }: { aspects = [ aspects.profile ]; })
      ];
    }).config;
  catalog =
    (lib.evalModules {
      modules = [
        (aspectLibrary.new-scope "composition")
        ../../../aspects
        ./tests/catalog.nix
      ];
    }).config.composition.aspects;
  catalogValues =
    class: aspect: lib.sort (a: b: a < b) (evaluate class [ aspect ]).config.test.values;
  empty = evaluate "nixos" [ ];
  cases = {
    workstationSystemModules =
      catalogValues "nixos" catalog.workstation == [
        "default-editor"
        "desktop"
        "nix-general"
      ];
    workstationUserModules =
      catalogValues "homeManager" catalog.workstation == [
        "rix101-firefox"
        "rix101-scm"
        "rix101-shell"
      ];
    riverSystemDependencyIsUnique =
      catalogValues "nixos" catalog.riverWorkstation == [
        "default-editor"
        "desktop"
        "nix-general"
      ];
    darwinWorkstationSystemModules =
      catalogValues "darwin" catalog.darwinWorkstation == [
        "brew"
        "nix-general"
        "system"
        "yabai"
      ];
    darwinWorkstationUserModules =
      catalogValues "homeManager" catalog.darwinWorkstation == [
        "rix101-scm"
        "rix101-shell"
        "rix101-wezterm"
      ];
    serverSystemModules =
      catalogValues "nixos" catalog.server == [
        "default-editor"
        "nix-general"
        "slskd"
        "taskchampion-sync-server"
        "vaultwarden"
      ];
    droidSystemDefaults = catalogValues "nixOnDroid" catalog.standardEnvironment == [ "nix-general" ];
    transitiveIncludes =
      lib.sort (a: b: a < b) (evaluate "nixos" [ transitive.root ]).config.test.values == [
        "leaf"
        "middle"
      ];
    diamondIncludesDeduplicateNativeFixture =
      (evaluate "nixos" [ diamond.root ]).config.test.shared == [ "shared" ];
    inlineAnonymousContributionsRemainDuplicated =
      inlineDuplicate.config.test.inline == [
        "anonymous"
        "anonymous"
      ];
    includesOnlyBundle = includeOnly.config.test.values == [ "included" ];
    classSelectionIsolated = selected.config.test.values == [ "nixos" ];
    unsupportedClassIsEmpty = (evaluate "liminix" [ catalog.workstation ]).config.test.values == [ ];
    parameterizedInstancesRetained =
      lib.sort (a: b: a < b)
        (evaluate "nixos" [
          (parameter "first")
          (parameter "second")
        ]).config.test.values == [
        "first"
        "second"
      ];
    resolveHostIncludesHostAndEveryUser =
      lib.sort (a: b: a < b) host.config.test.values == [
        "alice-system"
        "bob-system"
        "host"
      ];
    homeManagerForwardingIsPerUser =
      host.config.home-manager.users.alice.homeValues == [ "alice" ]
      && host.config.home-manager.users.bob.homeValues == [ "bob" ];
    hostOnlyHomeManagerFieldsStayAtHost =
      host.config.home-manager.users.alice.hostOnly == [ ]
      && host.config.home-manager.users.bob.hostOnly == [ ];
    unselectedUserReceivesNoFeatures = unselectedUser.config.home-manager.users.carol.homeValues == [ ];
    unknownNamedUserRejected = !unknownUser.success;
    nixOnDroidHomePath = droid.config.home-manager.config.homeValues == [ "droid-home" ];
    typedMetadataReferencesResolve =
      typedHost.config.test.values == [ "typed-system" ]
      && typedHost.config.home-manager.users.operator.homeValues == [ "typed-home" ];
    standaloneHomeMetadata =
      !(standaloneMetadata ? users)
      &&
        (lib.evalModules {
          class = "homeManager";
          modules = [
            { options.homeValues = listOption; }
            (composition.resolveModules "homeManager" standaloneMetadata.aspects)
          ];
        }).config.homeValues == [ "typed-home" ];
    emptySelection = empty.config.test.values == [ ];
  }
  // import ../modules/tests.nix { inherit lib; }
  // import ../things/tests.nix { inherit lib; }
  // import ../packages/tests.nix { inherit lib; };
in
{
  passed = builtins.all (case: case) (builtins.attrValues cases);
  inherit cases;
}
