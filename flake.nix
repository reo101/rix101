{
  description = "reo101's NixOS, nix-on-droid and nix-darwin configs";

  inputs = {
    # Nixpkgs
    nixpkgs = {
      # url = "github:nixos/nixpkgs/nixos-22.05";
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    # Nix on Droid
    nix-on-droid = {
      # url = "github:t184256/nix-on-droid/release-22.05";
      url = "github:t184256/nix-on-droid/master";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Nix Darwin
    nix-darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/release-22.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # hardware = {
    #   url = "github:nixos/nixos-hardware";
    # };

    # nix-colors = {
    #   url = "github:misterio77/nix-colors";
    # };

    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zls-overlay = {
      url = "github:zigtools/zls";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , nix-on-droid
    , nix-darwin
    , home-manager
    # , hardware
    # , nix-colors
    , neovim-nightly-overlay
    , zig-overlay
    , zls-overlay
    , ...
    } @ inputs:
    let
      inherit (self) outputs;
      inherit ((import ./lib/default.nix) { lib = nixpkgs.lib; })
        recurseDir
        hasFiles
        hasDirectories;
      forAllSystems = nixpkgs.lib.genAttrs [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
    in
    rec {
      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in import ./pkgs { inherit pkgs; }
      );

      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in import ./shell.nix { inherit pkgs; }
      );

      overlays = import ./overlays;

      # Modules
      nixosModules = import ./modules/nixos;
      nixOnDroidModules = import ./modules/nix-on-droid;
      nixDarwinModules = import ./modules/nix-darwin;
      homeManagerModules = import ./modules/home-manager;

      # Machines
      machines = recurseDir ./machines;
      homeManagerMachines = machines.home-manager or {};
      nixDarwinMachines = machines.nix-darwin or {};
      nixOnDroidMachines = machines.nix-on-droid or {};
      nixosMachines = machines.nixos or {};

      # mkHost helpers
      mkNixosHost = system: hostname: nixpkgs.lib.nixosSystem {
        modules = [
          ./machines/nixos/${system}/${hostname}/configuration.nix
        ];

        specialArgs = {
          inherit inputs outputs;
        };
      };

      mkNixOnDroidHost = system: hostname: nix-on-droid.lib.nixOnDroidConfiguration {
        pkgs = import nixpkgs {
          inherit system;

          overlays = [
            nix-on-droid.overlays.default
          ];
        };

        modules = [
          ./machines/nix-on-droid/${system}/${hostname}/configuration.nix
          { nix.registry.nixpkgs.flake = nixpkgs; }
        ] ++ (builtins.attrValues nixOnDroidModules);

        extraSpecialArgs = {
          inherit inputs outputs;
          # rootPath = ./.;
        };

        home-manager-path = home-manager.outPath;
      };

      mkNixDarwinHost = system: hostname: users: nix-darwin.lib.darwinSystem {
        inherit system;
        modules = [
          ./machines/nix-darwin/${system}/${hostname}/configuration.nix
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = false;
              useUserPackages = true;
              users = nixpkgs.lib.attrsets.genAttrs
                users
                (user: import ./machines/nix-darwin/${system}/${hostname}/home/${user}.nix);

              extraSpecialArgs = { inherit inputs; };
            };
          }
        ] ++ (builtins.attrValues nixDarwinModules);
        inputs = { inherit inputs outputs nix-darwin nixpkgs; };
      };

      mkHomeManagerHost = system: hostname: home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        modules = [
          ./machines/home-manager/${system}/${hostname}/home.nix
        ];
        extraSpecialArgs = { inherit inputs outputs; };
      };

      # Final configurations

      nixosConfigurations =
        nixpkgs.lib.foldAttrs
          (acc: x: acc)
          []
          (builtins.attrValues
            (builtins.mapAttrs
              (system: hosts:
                nixpkgs.lib.attrsets.filterAttrs
                  (host: config: config != null)
                  (builtins.mapAttrs
                    (host: config:
                      if (hasFiles [ "configuration.nix" ] config)
                        then mkNixosHost system host
                        else null)
                    hosts))
              nixosMachines));

      nixOnDroidConfigurations =
        nixpkgs.lib.foldAttrs
          (acc: x: acc)
          []
          (builtins.attrValues
            (builtins.mapAttrs
              (system: hosts:
                nixpkgs.lib.attrsets.filterAttrs
                  (host: config: config != null)
                  (builtins.mapAttrs
                    (host: config:
                      if (hasFiles [ "configuration.nix" "home.nix" ] config)
                        then mkNixOnDroidHost system host
                        else null)
                    hosts))
              nixOnDroidMachines));

      darwinConfigurations =
        nixpkgs.lib.foldAttrs
          (acc: x: acc)
          []
          (builtins.attrValues
            (builtins.mapAttrs
              (system: hosts:
                nixpkgs.lib.attrsets.filterAttrs
                  (host: config: config != null)
                  (builtins.mapAttrs
                    (host: config:
                      if (hasFiles [ "configuration.nix" ] config)
                        then mkNixDarwinHost system host
                              (builtins.map
                                (nixpkgs.lib.strings.removeSuffix ".nix")
                                (builtins.attrNames (config."home" or {})))
                        else null)
                    hosts))
              nixDarwinMachines));

      homeConfigurations =
        nixpkgs.lib.foldAttrs
          (acc: x: acc)
          []
          (builtins.attrValues
            (builtins.mapAttrs
              (system: hosts:
                nixpkgs.lib.attrsets.filterAttrs
                  (host: config: config != null)
                  (builtins.mapAttrs
                    (host: config:
                      if (hasFiles [ "home.nix" ] config)
                        then mkNixOnDroidHost system host
                        else null)
                    hosts))
              homeManagerMachines));
    };
}
