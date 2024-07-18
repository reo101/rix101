{ lib, config, self, inputs, ... }:

let
  inherit (inputs)
    nixpkgs;
  # TODO: works?
  outputs = self;
  inherit (import ./utils.nix { inherit lib self; })
    and
    hasFiles
    hasDirectories;
in
let
  # Configuration helpers
  mkNixosHost = root: system: hostname: users: lib.nixosSystem {
    inherit system;

    modules = [
      (lib.path.append root "configuration.nix")
      inputs.home-manager.nixosModules.home-manager
      inputs.nix-topology.nixosModules.default
      {
        nixpkgs.overlays = builtins.attrValues self.overlays;
      }
      {
        home-manager = {
          useGlobalPkgs = false;
          useUserPackages = true;
          users = lib.attrsets.genAttrs
            users
            (user: import (lib.path.append root "home/${user}.nix"));
          sharedModules = builtins.attrValues config.flake.homeManagerModules;
          extraSpecialArgs = {
            inherit inputs outputs;
            inherit hostname;
          };
        };
      }
      {
        networking.hostName = lib.mkDefault hostname;
      }
    ] ++ (builtins.attrValues config.flake.nixosModules);

    specialArgs = {
      inherit inputs outputs;
    };
  };

  mkNixOnDroidHost = root: system: hostname: inputs.nix-on-droid.lib.nixOnDroidConfiguration {
    pkgs = import nixpkgs {
      inherit system;

      overlays = builtins.attrValues self.overlays ++ [
        inputs.nix-on-droid.overlays.default
      ];
    };

    modules = [
      (lib.path.append root "configuration.nix")
      {
        home-manager = {
          config = (lib.path.append root "home.nix");
          backupFileExtension = "hm-bak";
          useGlobalPkgs = false;
          useUserPackages = true;
          sharedModules = builtins.attrValues config.flake.homeManagerModules ++ [
            {
              nixpkgs.overlays = builtins.attrValues self.overlays;
            }
          ];
          extraSpecialArgs = {
            inherit inputs outputs;
            inherit hostname;
          };
        };
      }
    ] ++ (builtins.attrValues config.flake.nixOnDroidModules);

    extraSpecialArgs = {
      inherit inputs outputs;
      inherit hostname;
      # rootPath = ./.;
    };

    home-manager-path = inputs.home-manager.outPath;
  };

  mkNixDarwinHost = root: system: hostname: users: inputs.nix-darwin.lib.darwinSystem {
    inherit system;

    modules = [
      (lib.path.append root "configuration.nix")
      {
        nixpkgs.hostPlatform = system;
      }
      {
        nixpkgs.overlays = builtins.attrValues self.overlays;
      }
      inputs.home-manager.darwinModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = false;
          useUserPackages = true;
          users = lib.attrsets.genAttrs
            users
            (user: import (lib.path.append root "home/${user}.nix"));
          sharedModules = builtins.attrValues config.flake.homeManagerModules;
          extraSpecialArgs = {
            inherit inputs outputs;
            inherit hostname;
          };
        };
      }
    ] ++ (builtins.attrValues config.flake.nixDarwinModules);

    specialArgs = {
      inherit inputs outputs;
    };
  };

  mkHomeManagerHost = root: system: hostname: inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = nixpkgs.legacyPackages.${system};

    modules = [
      (lib.path.append root "home.nix")
      {
        nixpkgs.overlays = builtins.attrValues self.overlays;
      }
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
          mkNixosHost
            ../machines/nixos/${system}/${host}
            system
            host
            (builtins.map
              (lib.strings.removeSuffix ".nix")
              (builtins.attrNames (configuration."home" or { }))))
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
          mkNixOnDroidHost
            ../machines/nix-on-droid/${system}/${host}
            system
            host)
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
          mkNixDarwinHost
            ../machines/nix-darwin/${system}/${host}
            system
            host
            (builtins.map
              (lib.strings.removeSuffix ".nix")
              (builtins.attrNames (configuration."home" or { }))))
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
          mkHomeManagerHost
            ../machines/home-manager/${system}/${host}
            system
            host)
        config.flake.homeManagerMachines;
  };
}
