{ lib, config, self, inputs, withSystem, ... }:

let
  inherit (config.lib)
    and
    hasFiles
    hasDirectories
    configuration-type-to-outputs-modules
    ;

  # `pkgs` with flake's overlays
  # NOTE: done here to avoid infinite recursion
  pkgs' = system:
    (withSystem system ({ pkgs, ... }: pkgs)).extend
      (final: prev: inputs.self.packages.${system});

  genUsers = configurationFiles:
    lib.pipe configurationFiles [
      (cf: cf."home" or { })
      builtins.attrNames
      (builtins.map
        (lib.strings.removeSuffix ".nix"))
    ];

  homeManagerModule = { root, meta, users ? null }: {
    home-manager = {
      # Use same `pkgs` instance as system (i.e. carry over overlays)
      useGlobalPkgs = true;
      # Do not keep packages in ${HOME}
      useUserPackages = true;
      # Default import all of our exported `home-manager` modules
      sharedModules = builtins.attrValues config.flake.${configuration-type-to-outputs-modules "home-manager"};
      # Pass in `inputs`, `hostname` and `meta`
      extraSpecialArgs = {
        inherit inputs;
        inherit meta;
      };
    } // (if users == null then {
      # nixOnDroid
      config = "${root}/home.nix";
    } else {
      # Not nixOnDroid
      users =
        lib.attrsets.genAttrs
          users
          (user: import "${root}/home/${user}.nix");
    });
  };

  mkNixosHost = args @ { root, meta, users }: inputs.nixpkgs.lib.nixosSystem {
    inherit (meta) system;
    pkgs = pkgs' meta.system;

    modules = [
      # Main configuration
      "${root}/configuration.nix"
      # Home Manager
      inputs.home-manager.nixosModules.home-manager
      (homeManagerModule args)
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
         # TODO: lib.optionals
    ] ++ (builtins.attrValues config.flake.${configuration-type-to-outputs-modules "nixos"});

    specialArgs = {
      inherit inputs;
      inherit meta;
    };
  };

  mkNixOnDroidHost = args @ { root, meta }: inputs.nix-on-droid.lib.nixOnDroidConfiguration {
    # NOTE: inferred by `pkgs.system`
    # inherit system;
    pkgs = pkgs' meta.system;

    modules = [
      # Main configuration
      "${root}/configuration.nix"
      # Home Manager
      (homeManagerModule args)
    ] ++ (builtins.attrValues config.flake.${configuration-type-to-outputs-modules "nix-on-droid"});

    extraSpecialArgs = {
      inherit inputs;
      inherit meta;
    };

    home-manager-path = inputs.home-manager.outPath;
  };

  mkNixDarwinHost = args @ { root, meta, users }: inputs.nix-darwin.lib.darwinSystem {
    inherit (meta) system;
    pkgs = pkgs' meta.system;

    modules = [
      # Main configuration
      "${root}/configuration.nix"
      # Home Manager
      inputs.home-manager.darwinModules.home-manager
      (homeManagerModule args)
    ] ++ (builtins.attrValues config.flake.${configuration-type-to-outputs-modules "nix-darwin"});

    specialArgs = {
      inherit inputs;
      inherit meta;
    };
  };

  mkHomeManagerHost = args @ { root, meta }: inputs.home-manager.lib.homeManagerConfiguration {
    inherit (meta) system;
    pkgs = pkgs' meta.system;

    modules = [
      "${root}/home.nix"
    ] ++ (builtins.attrValues config.flake.${configuration-type-to-outputs-modules "home-manager"});

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
        });
    };
  };
}
