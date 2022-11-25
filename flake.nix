{
  description = "reo101's NixOS, nix-on-droid and nix-on-darwin configs";

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

  outputs = { self
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
      nixosModules = import ./modules/nixos;
      nixOnDroidModules = import ./modules/nix-on-droid;
      nixDarwinModules = import ./modules/nix-darwin;
      homeManagerModules = import ./modules/home-manager;

      nixosConfigurations = {
        # arthur = nixpkgs.lib.nixosSystem {
        #   specialArgs = { inherit inputs outputs; };
        #   modules = [
        #     ./nixos/arthur/configuration.nix
        #   ];
        # };
      };

      nixOnDroidConfigurations =
        let mkHost = system: hostname: nix-on-droid.lib.nixOnDroidConfiguration {
          pkgs = import nixpkgs {
            inherit system;

            overlays = [
              nix-on-droid.overlays.default
            ];
          };

          modules = [
            ./nix-on-droid/${hostname}/configuration.nix
            { nix.registry.nixpkgs.flake = nixpkgs; }
          ] ++ (builtins.attrValues nixOnDroidModules);

          extraSpecialArgs = {
            inherit inputs outputs;
            # rootPath = ./.;
          };

          home-manager-path = home-manager.outPath;
        };
      in rec {
        cheetah = mkHost "aarch64-linux" "cheetah";

        default = cheetah;
      };

      darwinConfigurations =
        let mkHost = system: hostname: users: nix-darwin.lib.darwinSystem {
          inherit system;
          modules = [
            ./nix-darwin/${hostname}/configuration.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = false;
                useUserPackages = true;
                users = nixpkgs.lib.attrsets.genAttrs
                  users
                  (user: import ./nix-darwin/${hostname}/home/${user}.nix);

                extraSpecialArgs = { inherit inputs; };
              };
            }
          ] ++ (builtins.attrValues nixDarwinModules);
          inputs = { inherit inputs outputs nix-darwin nixpkgs; };
        };
        in
        rec {
          apavel-a01 = mkHost "x86_64-darwin" "apavel-a01" [ "apavel" ];
        };

      homeConfigurations = {
        # "nix-on-droid@cheetah" = home-manager.lib.homeManagerConfiguration {
        #   pkgs = nixpkgs.legacyPackages.x86_64-linux;
        #   extraSpecialArgs = { inherit inputs outputs; };
        #   modules = [
        #     ./home-manager/home.nix
        #   ];
        # };
      };
    };
}
