{
  inputs,
  self,
  lib,
  config,
  withSystem,
  ...
}:

let
  # HACK: doesn't get automatically overriden for some reason
  lib = config._module.args.lib;
  inherit (config.lib.custom)
    and
    hasNixFiles
    hasDirectories
    extractDirectory
    ;

  inputsFor = system: lib.mapAttrs (lib.const (config.perInput system)) inputs;

  # Global `pkgs` with flake's overlays and packages
  # See <../pkgs/default.nix>
  pkgsFor =
    system: selector:
    let
      inherit (config.perSystem system) pkgs;
    in
    # `null` -> main nixpkgs; raw instance name (any `nixpkgs-*` input) -> `pkgs.nixpkgs.<name>`;
    # otherwise -> nixpkgs-multiverse selector
    if builtins.isNull selector then pkgs
    else if pkgs.nixpkgs ? ${selector} then pkgs.nixpkgs.${selector}
    else pkgs.multiverse.at selector;

  genUsers =
    configurationFiles:
    lib.pipe configurationFiles [
      # Enter `home` subdirectory, if it exists
      (cf: extractDirectory cf "home")
      # Filter out only the nix files, extracting their contents
      (lib.concatMapAttrs (
        file: value:
        lib.optionalAttrs (value._type == "nix") {
          ${lib.strings.removeSuffix ".nix" file} = value.content;
        }
      ))
    ];

  composition = config.lib.composition;

  agenix-module-for =
    host-type:
    { meta, config, ... }:
    {
      imports = [
        inputs.ragenix."${lib.custom.kebabToCamel host-type}Modules".default
        inputs.agenix-rekey."${lib.custom.kebabToCamel host-type}Modules".default
        (lib.optionalAttrs (meta.pubkey != null) {
          age.rekey.hostPubkey = meta.pubkey;
        })
        (lib.modules.importApply ./agenix-rekey { inherit host-type; })
      ];
    };

  homeManagerModule =
    {
      meta,
      extraModules ? [ ],
    }:
    {
      home-manager = {
        # Use same `pkgs` instance as system (i.e. carry over overlays)
        useGlobalPkgs = true;
        # Do not keep packages in ${HOME}
        useUserPackages = true;
        # Shared modules provide framework support, not user feature selections.
        sharedModules = extraModules ++ [
          (
            { lib, ... }:
            {
              _module.args.lib = lib;
            }
          )
        ];
        # Pass in `inputs` and `meta`
        extraSpecialArgs = {
          inherit inputs;
          inputs' = inputsFor meta.system;
          inherit meta;
          # inherit lib;
        };
      };
    };

  mkNixosHost =
    {
      meta,
      configuration,
      users,
      extraModules ? [ ],
      extraHomeModules ? [ ],
    }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit (meta) system;
      pkgs = pkgsFor meta.system meta.nixpkgs;

      modules = [
        # Main configuration
        configuration

        # Home Manager
        inputs.home-manager.nixosModules.home-manager
        (homeManagerModule {
          inherit meta;
          extraModules = extraHomeModules;
        })
        { home-manager.users = users; }

        (composition.resolveHost {
          class = "nixos";
          inherit meta;
          userNames = builtins.attrNames users;
        })

        # nix-topology
        inputs.nix-topology.nixosModules.default

        # Sane default `networking.hostName`
        {
          networking.hostName = lib.mkDefault meta.hostname;
        }
      ]
      ++ extraModules;

      specialArgs = {
        inherit inputs;
        inputs' = inputsFor meta.system;
        inherit meta;
        inherit lib;
      };
    };

  mkNixOnDroidHost =
    {
      meta,
      configuration,
      homeConfiguration,
      extraModules ? [ ],
      extraHomeModules ? [ ],
    }:
    let
      userNames = builtins.attrNames meta.users;
    in
    assert lib.assertMsg (builtins.length userNames == 1)
      "Nix-on-Droid requires exactly one named Home Manager aspect binding";
    inputs.nix-on-droid.lib.nixOnDroidConfiguration {
      # NOTE: inferred by `pkgs.system`
      # inherit system;
      pkgs = pkgsFor meta.system meta.nixpkgs;

      modules = [
        # Main configuration
        configuration
        # Home Manager
        (homeManagerModule {
          inherit meta;
          extraModules = extraHomeModules ++ [
            ({ config, ... }: {
              assertions = [{
                assertion = config.home.username == builtins.head userNames;
                message = "Nix-on-Droid Home Manager username does not match its aspect binding";
              }];
            })
          ];
        })
        { home-manager.config = homeConfiguration; }
        (composition.resolveHost {
          class = "nixOnDroid";
          inherit meta userNames;
          homePath = _: [ "home-manager" "config" ];
        })
        # UID and GUI
        {
          user = {
            inherit (meta)
              uid
              gid
              ;
          };
        }
      ]
      ++ extraModules;

      extraSpecialArgs = {
        inherit inputs;
        inputs' = inputsFor meta.system;
        inherit meta;
        inherit lib;
      };

      home-manager-path = inputs.home-manager.outPath;
    };

  mkNixDarwinHost =
    {
      meta,
      configuration,
      users,
      extraModules ? [ ],
      extraHomeModules ? [ ],
    }:
    inputs.nix-darwin.lib.darwinSystem {
      inherit (meta) system;
      pkgs = pkgsFor meta.system meta.nixpkgs;

      modules = [
        # Main configuration
        configuration

        # Home Manager
        inputs.home-manager.darwinModules.home-manager
        (homeManagerModule {
          inherit meta;
          extraModules = extraHomeModules;
        })
        { home-manager.users = users; }
        (composition.resolveHost {
          class = "darwin";
          inherit meta;
          userNames = builtins.attrNames users;
        })
      ]
      ++ extraModules;

      specialArgs = {
        inherit inputs;
        inputs' = inputsFor meta.system;
        inherit meta;
        inherit lib;
      };
    };

  mkHomeManagerHost =
    {
      meta,
      configuration,
      extraModules ? [ ],
    }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = pkgsFor meta.system meta.nixpkgs;

      modules = [
        configuration
        (composition.resolveModules "homeManager" meta.aspects)
      ]
      ++ extraModules;

      extraSpecialArgs = {
        inherit inputs;
        inputs' = inputsFor meta.system;
        inherit meta;
        inherit lib;
      };
    };

  mkOpenwrt =
    {
      meta,
      configuration,
    }:
    let
      pkgs = pkgsFor meta.system meta.nixpkgs;
      cachePath = meta.cachePath or null;
      profiles = inputs.openwrt-imagebuilder.lib.profiles (
        {
          inherit pkgs;
          inherit (meta) release;
        }
        // lib.optionalAttrs (cachePath != null) {
          inherit cachePath;
        }
      );
      openwrtConfig =
        profiles.identifyProfile meta.profile
        // configuration { inherit pkgs lib; }
        // lib.optionalAttrs (cachePath != null) {
          inherit cachePath;
        };
    in
    inputs.openwrt-imagebuilder.lib.build openwrtConfig;

  mkLiminix =
    {
      meta,
      configuration,
    }:
    let
      liminix = inputs.liminix.outPath;
      outputs = (import "${liminix}/default.nix" {
        # Liminix configs are plain modules (evaluated with its own evalModules)
        liminix-config = {
          imports = [ configuration (composition.resolveModules "liminix" meta.aspects) ];
          _module.args = { inherit inputs meta; };
        };
        device = import "${liminix}/devices/${meta.device}";
        nixpkgs = inputs.nixpkgs;
        system = meta.system;
      }).outputs;
    in
    outputs;
in
{
  flake-file.inputs.tranquil = {
    url = "git+https://tangled.org/tranquil.farm/tranquil-pds";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  auto.configurations.configurationTypes = lib.mkDefault {
    nixos = {
      predicate = (
        { meta, configurationFiles, ... }:
        and [
          meta.enable
          (hasNixFiles [ "configuration.nix" ] configurationFiles)
        ]
      );
      metaModule =
        { lib, metaModules, ... }:
        {
          imports = [
            metaModules.enable
            metaModules.system
            metaModules.hostname
            metaModules.nixpkgs
            metaModules.pubkey
            metaModules.aspects
            metaModules.deploy
            metaModules.gui
            metaModules.wireguard
            metaModules.nix-build
          ];
        };
      mkHost = (
        { meta, configurationFiles, ... }:
        mkNixosHost {
          inherit meta;
          configuration = configurationFiles."configuration.nix".content;
          users = genUsers configurationFiles;
          extraModules = [
            (agenix-module-for "nixos")
            ../../nixos/nix-build
          ];
          extraHomeModules = [
            (agenix-module-for "homeManager")
          ];
        }
      );
      mkDeployNode = (
        { meta, configuration }:
        {
          inherit (meta.deploy) hostname;
          profiles.system = meta.deploy // {
            path = inputs.deploy-rs.lib.${meta.system}.activate."nixos" configuration;
          };
        }
      );
    };
    nix-on-droid = {
      predicate = (
        { meta, configurationFiles, ... }:
        and [
          meta.enable
          (hasNixFiles [ "configuration.nix" "home.nix" ] configurationFiles)
        ]
      );
      metaModule =
        { lib, metaModules, ... }:
        {
          imports = [
            metaModules.enable
            metaModules.system
            metaModules.hostname
            metaModules.nixpkgs
            metaModules.pubkey
            metaModules.aspects
            metaModules.deploy
          ];

          options =
            let
              inherit (lib)
                mkOption
                types
                ;
            in
            {
              uid = mkOption {
                type = types.ints.positive;
              };
              gid = mkOption {
                type = types.ints.positive;
              };
            };
        };
      mkHost = (
        { meta, configurationFiles, ... }:
        mkNixOnDroidHost {
          inherit meta;
          configuration = configurationFiles."configuration.nix".content;
          homeConfiguration = configurationFiles."home.nix".content;
        }
      );
      mkDeployNode = (
        { meta, configuration }:
        {
          inherit (meta.deploy) hostname;
          profiles.system = meta.deploy // {
            path =
              inputs.deploy-rs.lib.${meta.system}.activate.custom configuration.activationPackage
                "${configuration.activationPackage}/activate";
          };
        }
      );
    };
    nix-darwin = {
      hostsName = "darwinHosts";
      configurationsName = {
        old = "darwinConfigurations";
        new = "darwin";
      };
      predicate = (
        { meta, configurationFiles, ... }:
        and [
          meta.enable
          (hasNixFiles [ "configuration.nix" ] configurationFiles)
          (hasDirectories [ "home" ] configurationFiles)
        ]
      );
      metaModule =
        { lib, metaModules, ... }:
        {
          imports = [
            metaModules.enable
            metaModules.system
            metaModules.hostname
            metaModules.nixpkgs
            metaModules.pubkey
            metaModules.aspects
            metaModules.deploy
          ];
        };
      mkHost = (
        { meta, configurationFiles, ... }:
        mkNixDarwinHost {
          inherit meta;
          configuration = configurationFiles."configuration.nix".content;
          users = genUsers configurationFiles;
          extraModules = [
            (agenix-module-for "darwin")
          ];
          extraHomeModules = [
            (agenix-module-for "homeManager")
          ];
        }
      );
      mkDeployNode = (
        { meta, configuration }:
        {
          inherit (meta.deploy) hostname;
          profiles.system = meta.deploy // {
            path = inputs.deploy-rs.lib.${meta.system}.activate."darwin" configuration;
          };
        }
      );
    };
    home-manager = {
      hostsName = "homeHosts";
      configurationsName = {
        old = "homeConfigurations";
        new = "home";
      };
      predicate = (
        { meta, configurationFiles, ... }:
        and [
          meta.enable
          (hasNixFiles [ "home.nix" ] configurationFiles)
        ]
      );
      metaModule =
        { lib, metaModules, ... }:
        {
          imports = [
            metaModules.enable
            metaModules.system
            metaModules.hostname
            metaModules.aspects
            metaModules.nixpkgs
            # metaModules.pubkey
          ];
        };
      mkHost = (
        { meta, configurationFiles, ... }:
        mkHomeManagerHost {
          inherit meta;
          configuration = configurationFiles."home.nix".content;
        }
      );
    };
    openwrt = {
      predicate = (
        { meta, configurationFiles, ... }:
        and [
          meta.enable
          (hasNixFiles [ "configuration.nix" ] configurationFiles)
        ]
      );      metaModule =
        { lib, metaModules, ... }:
        {
          imports = [
            metaModules.enable
            metaModules.system
            metaModules.nixpkgs
            metaModules.openwrt
          ];

          options =
            let
              inherit (lib)
                mkOption
                types
                ;
            in
            {
              release = mkOption {
                type = types.str;
              };
              profile = mkOption {
                type = types.str;
              };
              cachePath = mkOption {
                type = types.nullOr types.path;
                description = ''
                  Optional path to a nix-openwrt-imagebuilder cache release directory.
                  You can point this to `${self}/modules/flake/configurations/openwrt-cache/<release>`
                  to reuse a repository-local shared cache override.
                  Useful when upstream package indexes drift before the input cache is refreshed.
                '';
                default = null;
              };
            };
        };
      mkHost = (
        { meta, configurationFiles, ... }:
        mkOpenwrt {
          inherit meta;
          configuration = configurationFiles."configuration.nix".content;
        }
      );
    };

    liminix = {
      predicate = (
        { meta, configurationFiles, ... }:
        and [
          meta.enable
          (hasNixFiles [ "configuration.nix" ] configurationFiles)
        ]
      );
      metaModule =
        { lib, metaModules, ... }:
        {
          imports = [
            metaModules.enable
            metaModules.system
            metaModules.aspects
            metaModules.nixpkgs
          ];

          options.device = lib.mkOption {
            type = lib.types.str;
            description = "Liminix device, i.e. a dir name under upstream `devices/`";
            example = "openwrt-one";
          };
        };
      mkHost = (
        { meta, configurationFiles, ... }:
        mkLiminix {
          inherit meta;
          configuration = configurationFiles."configuration.nix".content;
        }
      );
    };
  };
}
