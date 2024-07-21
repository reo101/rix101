{ lib, config, self, inputs, withSystem, ... }:

let
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
      # (r)agenix && agenix-rekey
      inputs.ragenix.nixosModules.default
      inputs.agenix-rekey.nixosModules.default
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
              (host: configurationFiles:
                lib.optionalAttrs
                  (and [
                    (host != "__template__")
                    (pred { inherit system host configurationFiles; })
                  ])
                  {
                    ${host} = mkHost { inherit system host configurationFiles; };
                  })
              hosts)
          machines));
in
{
  imports = [
    ./machines.nix
  ];

  flake = {
    # Configurations
    nixosConfigurations =
      createConfigurations
        ({ system, host, configurationFiles, ... }:
          and
            [
              (hasFiles
                [ "configuration.nix" ]
                configurationFiles)
              # (hasDirectories
              #   [ "home" ]
              #   config)
            ])
        ({ system, host, configurationFiles, ... }:
          mkNixosHost {
            root = ../machines/nixos/${system}/${host};
            inherit system;
            hostname = host;
            users = (builtins.map
              (lib.strings.removeSuffix ".nix")
              (builtins.attrNames (configurationFiles."home" or { })));
          })
        config.flake.nixosMachines;

    nixOnDroidConfigurations =
      createConfigurations
        ({ system, host, configurationFiles, ... }:
          and
            [
              (hasFiles
                [ "configuration.nix" "home.nix" ]
                configurationFiles)
            ])
        ({ system, host, configurationFiles, ... }:
          mkNixOnDroidHost {
            root = ../machines/nix-on-droid/${system}/${host};
            inherit system;
            hostname = host;
          })
        config.flake.nixOnDroidMachines;

    darwinConfigurations =
      createConfigurations
        ({ system, host, configurationFiles, ... }:
          and
            [
              (hasFiles
                [ "configuration.nix" ]
                configurationFiles)
              (hasDirectories
                [ "home" ]
                configurationFiles)
            ])
        ({ system, host, configurationFiles, ... }:
          mkNixDarwinHost {
            root = ../machines/nix-darwin/${system}/${host};
            inherit system;
            hostname = host;
            users = (builtins.map
              (lib.strings.removeSuffix ".nix")
              (builtins.attrNames (configurationFiles."home" or { })));
          })
        config.flake.nixDarwinMachines;

    homeConfigurations =
      createConfigurations
        ({ system, host, configurationFiles, ... }:
          and
            [
              (hasFiles
                [ "home.nix" ]
                configurationFiles)
            ])
        ({ system, host, configurationFiles, ... }:
          mkHomeManagerHost {
            root = ../machines/home-manager/${system}/${host};
            inherit system;
            hostname = host;
          })
        config.flake.homeManagerMachines;
  };
}
