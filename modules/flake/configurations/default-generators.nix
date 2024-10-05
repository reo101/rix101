{ lib, config, self, inputs, withSystem, ... }:

let
  inherit (config.lib)
    and
    hasNixFiles
    hasDirectories
    extractDirectory
    ;

  # `pkgs` with flake's overlays
  pkgsFor = system:
    lib.pipe (withSystem system ({ pkgs, ... }: pkgs)) [
      # NOTE: flake's packages, done here to avoid infinite recursion
      (p: p.extend
        (final: prev: inputs.self.packages.${system}))
    ];

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
      # Default import all of our exported `home-manager` modules
      sharedModules = builtins.attrValues config.flake.${config.auto.modules.moduleTypes."home-manager".modulesName};
      # Pass in `inputs` and `meta`
      extraSpecialArgs = {
        inherit inputs;
        inherit meta;
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
      # (r)agenix && agenix-rekey
      inputs.ragenix.nixosModules.default
      inputs.agenix-rekey.nixosModules.default
      (lib.optionalAttrs (meta.pubkey != null) {
        age.rekey.hostPubkey = meta.pubkey;
      })
      ./agenix-rekey
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
    };
  };

  mkNixOnDroidHost = {
    meta,
    configuration,
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
        extraModules = extraHomeModules;
      })
    ] ++ extraModules;

    extraSpecialArgs = {
      inherit inputs;
      inherit meta;
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
    };
  };
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
      mkHost = ({ meta, configurationFiles, ... }:
        mkNixosHost {
          inherit meta;
          configuration = configurationFiles."configuration.nix".content;
          users = genUsers configurationFiles;
          extraModules = builtins.attrValues config.flake.nixosModules;
          extraHomeModules = builtins.attrValues config.flake.homeManagerModules;
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
      mkHost = ({ meta, configurationFiles, ... }:
        mkNixOnDroidHost {
          inherit meta;
          configuration = configurationFiles."configuration.nix".content;
          users = null;
          extraModules = builtins.attrValues config.flake.nixOnDroidModules;
          extraHomeModules = builtins.attrValues config.flake.homeManagerModules;
        });
    };
    nix-darwin = {
      hostsName = "darwinHosts";
      configurationsName = "darwinConfigurations";
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
      mkHost = ({ meta, configurationFiles, ... }:
        mkNixDarwinHost {
          inherit meta;
          configuration = configurationFiles."configuration.nix".content;
          users = genUsers configurationFiles;
          extraModules = builtins.attrValues config.flake.darwinModules;
          extraHomeModules = builtins.attrValues config.flake.homeManagerModules;
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
      configurationsName = "homeConfigurations";
      predicate = ({ meta, configurationFiles, ... }:
        and [
          meta.enable
          (hasNixFiles
            [ "home.nix" ]
            configurationFiles)
        ]);
      mkHost = ({ meta, configurationFiles, ... }:
        mkHomeManagerHost {
          inherit meta;
          configuration = configurationFiles."home.nix".content;
          extraModules = builtins.attrValues config.flake.homeManagerModules;
        });
    };
  };
}
