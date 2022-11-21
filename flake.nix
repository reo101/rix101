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
  };

  outputs = { self
            , nixpkgs
            , nix-on-droid
            , home-manager
            # , hardware
            # , nix-colors
            , neovim-nightly-overlay
            , zig-overlay
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
