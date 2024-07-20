{ lib, config, self, inputs, withSystem, ... }:

let
  # TODO: works?
  outputs = self;
  inherit (import ./utils.nix { inherit lib self; })
    and
    hasFiles
    hasDirectories;
in
let
  homeManagerModule = { root, system, hostname, users ? null }: {
    home-manager = {
      # Use same `pkgs` instance as system (i.e. carry over overlays)
      useGlobalPkgs = true;
      # Do not keep packages in ${HOME}
      useUserPackages = true;
      # Default import all of our exported homeManagerModules
      sharedModules = builtins.attrValues config.flake.homeManagerModules;
      # Pass in `inputs`, `outputs` and maybe `meta`
      extraSpecialArgs = {
        inherit inputs outputs;
        # TODO: meta?
        inherit hostname;
      };
    } // (if users == null then {
      # nixOnDroid
      config = (lib.path.append root "home.nix");
    } else {
      # Not nixOnDroid
      users = lib.attrsets.genAttrs
        users
          (user: import (lib.path.append root "home/${user}.nix"));
    });
  };

  # Configuration helpers
  mkNixosHost = args @ { root, system, hostname, users }: lib.nixosSystem {
    inherit system;
    pkgs = withSystem system ({ pkgs, ... }: pkgs);

    modules = [
      # Main configuration
      (lib.path.append root "configuration.nix")
      # Home Manager
      inputs.home-manager.nixosModules.home-manager
      (homeManagerModule args)
      # nix-topology
      inputs.nix-topology.nixosModules.default
      # Sane default `networking.hostName`
      {
        networking.hostName = lib.mkDefault hostname;
      }
    ] ++ (builtins.attrValues config.flake.nixosModules);

    specialArgs = {
      inherit inputs outputs;
    };
  };

  mkNixOnDroidHost = args @ { root, system, hostname }: inputs.nix-on-droid.lib.nixOnDroidConfiguration {
    # NOTE: inferred by `pkgs.system`
    # inherit system;
    pkgs = withSystem system ({ pkgs, ... }: pkgs);

    modules = [
      # Main configuration
      (lib.path.append root "configuration.nix")
      # Home Manager
      (homeManagerModule args)
    ] ++ (builtins.attrValues config.flake.nixOnDroidModules);

    extraSpecialArgs = {
      inherit inputs outputs;
    };

    home-manager-path = inputs.home-manager.outPath;
  };

  mkNixDarwinHost = args @ { root, system, hostname, users }: inputs.nix-darwin.lib.darwinSystem {
    inherit system;
    pkgs = withSystem system ({ pkgs, ... }: pkgs);

    modules = [
      # Main configuration
      (lib.path.append root "configuration.nix")
      # Home Manager
      inputs.home-manager.darwinModules.home-manager
      (homeManagerModule args)
      # # Set `nixpkgs.hostPlatform`
      # {
      #   nixpkgs.hostPlatform = system;
      # }
    ] ++ (builtins.attrValues config.flake.nixDarwinModules);

    specialArgs = {
      inherit inputs outputs;
    };
  };

  mkHomeManagerHost = args @ { root, system, hostname }: inputs.home-manager.lib.homeManagerConfiguration {
    inherit system;
    pkgs = withSystem system ({ pkgs, ... }: pkgs);

    modules = [
      (lib.path.append root "home.nix")
    ] ++ (builtins.attrValues config.flake.homeManagerModules);

    extraSpecialArgs = {
      inherit inputs outputs;
      inherit hostname;
    };
  };

  createConfigurations =
    pred: mkHost: machines:
    lib.foldAttrs
      lib.const
      [ ]
      (builtins.attrValues
        (builtins.mapAttrs
          (system: hosts:
            lib.concatMapAttrs
              (host: configuration:
                lib.optionalAttrs
                  (and [
                    (host != "__template__")
                    (pred system host configuration)
                  ])
                  {
                    ${host} = mkHost system host configuration;
                  })
              hosts)
          machines));
in
{
  flake = {
    # Configurations
    nixosConfigurations =
      createConfigurations
        (system: host: configuration:
          and
            [
              (hasFiles
                [ "configuration.nix" ]
                configuration)
              # (hasDirectories
              #   [ "home" ]
              #   config)
            ])
        (system: host: configuration:
          mkNixosHost {
            root = ../machines/nixos/${system}/${host};
            inherit system;
            hostname = host;
            users = (builtins.map
              (lib.strings.removeSuffix ".nix")
              (builtins.attrNames (configuration."home" or { })));
          })
        config.flake.nixosMachines;

    nixOnDroidConfigurations =
      createConfigurations
        (system: host: configuration:
          and
            [
              (hasFiles
                [ "configuration.nix" "home.nix" ]
                configuration)
            ])
        (system: host: configuration:
          mkNixOnDroidHost {
            root = ../machines/nix-on-droid/${system}/${host};
            inherit system;
            hostname = host;
          })
        config.flake.nixOnDroidMachines;

    darwinConfigurations =
      createConfigurations
        (system: host: configuration:
          and
            [
              (hasFiles
                [ "configuration.nix" ]
                configuration)
              (hasDirectories
                [ "home" ]
                configuration)
            ])
        (system: host: configuration:
          mkNixDarwinHost {
            root = ../machines/nix-darwin/${system}/${host};
            inherit system;
            hostname = host;
            users = (builtins.map
              (lib.strings.removeSuffix ".nix")
              (builtins.attrNames (configuration."home" or { })));
          })
        config.flake.nixDarwinMachines;

    homeConfigurations =
      createConfigurations
        (system: host: configuration:
          and
            [
              (hasFiles
                [ "home.nix" ]
                configuration)
            ])
        (system: host: configuration:
          mkHomeManagerHost {
            root = ../machines/home-manager/${system}/${host};
            inherit system;
            hostname = host;
          })
        config.flake.homeManagerMachines;
  };
}
