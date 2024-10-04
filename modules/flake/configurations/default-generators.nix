{ lib, config, self, inputs, withSystem, ... }:

let
  inherit (config.lib)
    and
    hasFiles
    hasDirectories
    ;

  # `pkgs` with flake's overlays
  # NOTE: done here to avoid infinite recursion
  pkgsFor = system:
    (withSystem system ({ pkgs, ... }: pkgs)).extend
      (final: prev: inputs.self.packages.${system});

  genUsers = configurationFiles:
    lib.pipe configurationFiles [
      (cf: cf."home" or { })
      builtins.attrNames
      (builtins.map
        (lib.strings.removeSuffix ".nix"))
    ];

  homeManagerModule = {
    root,
    meta,
    # NOTE: `[]` is default for normal systems
    #       set to `null` for `nixOnDroid`
    users ? [],
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
    } // (if users != null then {
      # Not nixOnDroid
      users =
        lib.attrsets.genAttrs
          users
          (user: import "${root}/home/${user}.nix");
    } else {
      # nixOnDroid
      config = "${root}/home.nix";
    });
  };

  mkNixosHost = args @ {
    root,
    meta,
    users,
    extraModules ? [],
    extraHomeModules ? [],
  }: inputs.nixpkgs.lib.nixosSystem {
    inherit (meta) system;
    pkgs = pkgsFor meta.system;

    modules = [
      # Main configuration
      "${root}/configuration.nix"
      # Home Manager
      inputs.home-manager.nixosModules.home-manager
      (homeManagerModule {
        inherit root meta users;
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

  mkNixOnDroidHost = args @ {
    root,
    meta,
    extraModules ? [],
    extraHomeModules ? [],
  }: inputs.nix-on-droid.lib.nixOnDroidConfiguration {
    # NOTE: inferred by `pkgs.system`
    # inherit system;
    pkgs = pkgsFor meta.system;

    modules = [
      # Main configuration
      "${root}/configuration.nix"
      # Home Manager
      (homeManagerModule {
        inherit root meta;
        extraModules = extraHomeModules;
      })
    ] ++ extraModules;

    extraSpecialArgs = {
      inherit inputs;
      inherit meta;
    };

    home-manager-path = inputs.home-manager.outPath;
  };

  mkNixDarwinHost = args @ {
    root,
    meta,
    users,
    extraModules ? [],
    extraHomeModules ? [],
  }: inputs.nix-darwin.lib.darwinSystem {
    inherit (meta) system;
    pkgs = pkgsFor meta.system;

    modules = [
      # Main configuration
      "${root}/configuration.nix"
      # Home Manager
      inputs.home-manager.darwinModules.home-manager
      (homeManagerModule {
        inherit root meta users;
        extraModules = extraHomeModules;
      })
    ] ++ extraModules;

    specialArgs = {
      inherit inputs;
      inherit meta;
    };
  };

  mkHomeManagerHost = args @ {
    root,
    meta,
    extraModules ? [],
  }: inputs.home-manager.lib.homeManagerConfiguration {
    inherit (meta) system;
    pkgs = pkgsFor meta.system;

    modules = [
      "${root}/home.nix"
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
      predicate = ({ root, meta, configurationFiles, ... }:
        and [
          meta.enable
          (hasFiles
            [ "configuration.nix" ]
            configurationFiles)
        ]);
      mkHost = ({ root, meta, configurationFiles, ... }:
        mkNixosHost {
          inherit root;
          inherit meta;
          users = genUsers configurationFiles;
          extraModules = builtins.attrValues config.flake.nixosModules;
          extraHomeModules = builtins.attrValues config.flake.homeManagerModules;
        });
      mkDeployNode = ({ root, meta, configuration }:
        {
          inherit (meta.deploy) hostname;
          profiles.system = meta.deploy // {
            path = inputs.deploy-rs.lib.${meta.system}.activate."nixos" configuration;
          };
        });
    };
    nix-on-droid = {
      predicate = ({ root, meta, configurationFiles, ... }:
        and [
          meta.enable
          (hasFiles
            [ "configuration.nix" "home.nix" ]
            configurationFiles)
        ]);
      mkHost = ({ root, meta, configurationFiles, ... }:
        mkNixOnDroidHost {
          inherit root;
          inherit meta;
          users = null;
          extraModules = builtins.attrValues config.flake.nixOnDroidModules;
          extraHomeModules = builtins.attrValues config.flake.homeManagerModules;
        });
    };
    nix-darwin = {
      hostsName = "darwinHosts";
      configurationsName = "darwinConfigurations";
      predicate = ({ root, meta, configurationFiles, ... }:
        and [
          meta.enable
          (hasFiles
            [ "configuration.nix" ]
            configurationFiles)
          (hasDirectories
            [ "home" ]
            configurationFiles)
        ]);
      mkHost = ({ root, meta, configurationFiles, ... }:
        mkNixDarwinHost {
          inherit root;
          inherit meta;
          users = genUsers configurationFiles;
          extraModules = builtins.attrValues config.flake.darwinModules;
          extraHomeModules = builtins.attrValues config.flake.homeManagerModules;
        });
      mkDeployNode = ({ root, meta, configuration }:
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
      predicate = ({ root, meta, configurationFiles, ... }:
        and [
          meta.enable
          (hasFiles
            [ "home.nix" ]
            configurationFiles)
        ]);
      mkHost = ({ root, meta, configurationFiles, ... }:
        mkHomeManagerHost {
          inherit root;
          inherit meta;
          extraModules = builtins.attrValues config.flake.homeManagerModules;
        });
    };
  };
}
