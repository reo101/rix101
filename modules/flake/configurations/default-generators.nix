{ lib, config, self, inputs, withSystem, ... }:

let
  # HACK: doesn't get automatically overriden for some reason
  lib = config._module.args.lib;
  inherit (config.lib)
    and
    hasNixFiles
    hasDirectories
    extractDirectory
    ;

  # Global `pkgs` with flake's overlays and packages
  # See <../pkgs/default.nix>
  pkgsFor = system: (config.perSystem system).pkgs;

  genUsers = configurationFiles:
    lib.pipe configurationFiles [
      # Enter `home` subdirectory, if it exists
      (cf: extractDirectory cf "home")
      # Filter out only the nix files, extracting their contents
      (lib.concatMapAttrs
        (file: value:
          lib.optionalAttrs
            (value._type == "nix")
            {
              ${lib.strings.removeSuffix ".nix" file} = value.content;
            }))
    ];

  agenix-module-for = host-type: { meta, ... }: {
    imports = [
      inputs.ragenix."${config.lib.kebabToCamel host-type}Modules".default
      inputs.agenix-rekey."${config.lib.kebabToCamel host-type}Modules".default
      (lib.optionalAttrs (meta.pubkey != null) {
        age.rekey.hostPubkey = meta.pubkey;
      })
      ./agenix-rekey
    ];
  };

  homeManagerModule = {
    meta,
    # NOTE: `{}` is default for normal systems
    #       set to module directly for `nixOnDroid`
    # FIXME: `nixOnDroid` module has to not be an attrset
    users ? {},
    extraModules ? [],
  }: {
    home-manager = {
      # Use same `pkgs` instance as system (i.e. carry over overlays)
      useGlobalPkgs = true;
      # Do not keep packages in ${HOME}
      useUserPackages = true;
      # Default import provided modules
      # Usually `builtins.attrValues config.flake.${config.auto.modules.moduleTypes."home-manager".modulesName}`
      sharedModules = extraModules ++ [
        ({ lib, ... }: {
          _module.args.lib = lib.extend inputs.nix-lib-net.overlays.raw;
        })
      ];
      # Pass in `inputs` and `meta`
      extraSpecialArgs = {
        inherit inputs;
        inherit meta;
        # inherit lib;
      };
    } // (if builtins.isAttrs users then {
      # Not nixOnDroid
      inherit users;
    } else {
      # nixOnDroid
      config = users;
    });
  };

  mkNixosHost = {
    meta,
    configuration,
    users,
    extraModules ? [],
    extraHomeModules ? [],
  }: inputs.nixpkgs.lib.nixosSystem {
    inherit (meta) system;
    pkgs = pkgsFor meta.system;

    modules = [
      # Main configuration
      configuration

      # Home Manager
      inputs.home-manager.nixosModules.home-manager
      (homeManagerModule {
        inherit meta users;
        extraModules = extraHomeModules;
      })

      # nix-topology
      inputs.nix-topology.nixosModules.default

      # Sane default `networking.hostName`
      {
        networking.hostName = lib.mkDefault meta.hostname;
      }
    ] ++ extraModules;

    specialArgs = {
      inherit inputs;
      inherit meta;
      inherit lib;
    };
  };

  mkNixOnDroidHost = {
    meta,
    configuration,
    homeConfiguration,
    extraModules ? [],
    extraHomeModules ? [],
  }: inputs.nix-on-droid.lib.nixOnDroidConfiguration {
    # NOTE: inferred by `pkgs.system`
    # inherit system;
    pkgs = pkgsFor meta.system;

    modules = [
      # Main configuration
      configuration
      # Home Manager
      (homeManagerModule {
        inherit meta;
        users = homeConfiguration;
        extraModules = extraHomeModules;
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
    ] ++ extraModules;

    extraSpecialArgs = {
      inherit inputs;
      inherit meta;
      inherit lib;
    };

    home-manager-path = inputs.home-manager.outPath;
  };

  mkNixDarwinHost = {
    meta,
    configuration,
    users,
    extraModules ? [],
    extraHomeModules ? [],
  }: inputs.nix-darwin.lib.darwinSystem {
    inherit (meta) system;
    pkgs = pkgsFor meta.system;

    modules = [
      # Main configuration
      configuration

      # (r)agenix && agenix-rekey
      inputs.ragenix.darwinModules.default
      inputs.agenix-rekey.nixosModules.default
      (lib.optionalAttrs (meta.pubkey != null) {
        age.rekey.hostPubkey = meta.pubkey;
      })
      ./agenix-rekey

      # Home Manager
      inputs.home-manager.darwinModules.home-manager
      (homeManagerModule {
        inherit meta users;
        extraModules = extraHomeModules;
      })
    ] ++ extraModules;

    specialArgs = {
      inherit inputs;
      inherit meta;
      inherit lib;
    };
  };

  mkHomeManagerHost = {
    meta,
    configuration,
    extraModules ? [],
  }: inputs.home-manager.lib.homeManagerConfiguration {
    inherit (meta) system;
    pkgs = pkgsFor meta.system;

    modules = [
      configuration
    ] ++ extraModules;

    extraSpecialArgs = {
      inherit inputs;
      inherit meta;
      inherit lib;
    };
  };

  mkOpenwrt = {
    meta,
    configuration,
  }: let
    pkgs = pkgsFor meta.system;
    profiles = inputs.openwrt-imagebuilder.lib.profiles {
      inherit pkgs;
      inherit (meta) release;
    };
    openwrtConfig = profiles.identifyProfile meta.profile // configuration { inherit pkgs lib; };
  in inputs.openwrt-imagebuilder.lib.build openwrtConfig;
in
{
  auto.configurations.configurationTypes = lib.mkDefault {
    nixos = {
      predicate = ({ meta, configurationFiles, ... }:
        and [
          meta.enable
          (hasNixFiles
            [ "configuration.nix" ]
            configurationFiles)
        ]);
      metaModule = { lib, metaModules, ... }: {
        imports = [
          metaModules.enable
          metaModules.system
          metaModules.hostname
          metaModules.pubkey
          metaModules.deploy
          metaModules.gui
        ];
      };
      mkHost = ({ meta, configurationFiles, ... }:
        mkNixosHost {
          inherit meta;
          configuration = configurationFiles."configuration.nix".content;
          users = genUsers configurationFiles;
          extraModules = builtins.attrValues config.flake.nixosModules ++ [
            (agenix-module-for "nixos")
          ];
          extraHomeModules = builtins.attrValues config.flake.homeManagerModules ++ [
            (agenix-module-for "homeManager")
          ];
        });
      mkDeployNode = ({ meta, configuration }:
        {
          inherit (meta.deploy) hostname;
          profiles.system = meta.deploy // {
            path = inputs.deploy-rs.lib.${meta.system}.activate."nixos" configuration;
          };
        });
    };
    nix-on-droid = {
      predicate = ({ meta, configurationFiles, ... }:
        and [
          meta.enable
          (hasNixFiles
            [ "configuration.nix" "home.nix" ]
            configurationFiles)
        ]);
      metaModule = { lib, metaModules, ... }: {
        imports = [
          metaModules.enable
          metaModules.system
          metaModules.hostname
          metaModules.pubkey
          metaModules.deploy
        ];

        options = let
          inherit (lib)
            mkOption
            types
            ;
        in {
          uid = mkOption {
            type = types.ints.positive;
          };
          gid = mkOption {
            type = types.ints.positive;
          };
        };
      };
      mkHost = ({ meta, configurationFiles, ... }:
        mkNixOnDroidHost {
          inherit meta;
          configuration = configurationFiles."configuration.nix".content;
          homeConfiguration = configurationFiles."home.nix".content;
          extraModules = builtins.attrValues config.flake.nixOnDroidModules;
          extraHomeModules = builtins.attrValues config.flake.homeManagerModules;
        });
      mkDeployNode = ({ meta, configuration }:
        {
          inherit (meta.deploy) hostname;
          profiles.system = meta.deploy // {
            path = inputs.deploy-rs.lib.${meta.system}.activate.custom
              configuration.activationPackage
              "${configuration.activationPackage}/activate";
          };
        });
    };
    nix-darwin = {
      hostsName = "darwinHosts";
      configurationsNameOld = "darwinConfigurations";
      configurationsNameNew = "darwin";
      predicate = ({ meta, configurationFiles, ... }:
        and [
          meta.enable
          (hasNixFiles
            [ "configuration.nix" ]
            configurationFiles)
          (hasDirectories
            [ "home" ]
            configurationFiles)
        ]);
      metaModule = { lib, metaModules, ... }: {
        imports = [
          metaModules.enable
          metaModules.system
          metaModules.hostname
          metaModules.pubkey
          metaModules.deploy
        ];
      };
      mkHost = ({ meta, configurationFiles, ... }:
        mkNixDarwinHost {
          inherit meta;
          configuration = configurationFiles."configuration.nix".content;
          users = genUsers configurationFiles;
          extraModules = builtins.attrValues config.flake.darwinModules;
          extraHomeModules = builtins.attrValues config.flake.homeManagerModules ++ [
            # (agenix-module-for "darwin")
          ];
        });
      mkDeployNode = ({ meta, configuration }:
        {
          inherit (meta.deploy) hostname;
          profiles.system = meta.deploy // {
            path = inputs.deploy-rs.lib.${meta.system}.activate."darwin" configuration;
          };
        });
    };
    home-manager = {
      hostsName = "homeHosts";
      configurationsNameOld = "homeConfigurations";
      configurationsNameNew = "home";
      predicate = ({ meta, configurationFiles, ... }:
        and [
          meta.enable
          (hasNixFiles
            [ "home.nix" ]
            configurationFiles)
        ]);
      metaModule = { lib, metaModules, ... }: {
        imports = [
          metaModules.enable
          metaModules.system
          metaModules.hostname
          # metaModules.pubkey
        ];
      };
      mkHost = ({ meta, configurationFiles, ... }:
        mkHomeManagerHost {
          inherit meta;
          configuration = configurationFiles."home.nix".content;
          extraModules = builtins.attrValues config.flake.homeManagerModules;
        });
    };
    openwrt = {
      predicate = ({ meta, configurationFiles, ... }:
        and [
          meta.enable
          (hasNixFiles
            [ "configuration.nix" ]
            configurationFiles)
        ]);
      metaModule = { lib, metaModules, ... }: {
        imports = [
          metaModules.enable
          metaModules.system
        ];

        options = let
          inherit (lib)
            mkOption
            types;
        in {
          release = mkOption {
            type = types.str;
          };
          profile = mkOption {
            type = types.str;
          };
        };
      };
      mkHost = ({ meta, configurationFiles, ... }:
        mkOpenwrt {
          inherit meta;
          configuration = configurationFiles."configuration.nix".content;
        });
    };
  };
}
