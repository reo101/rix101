{
  description = "reo101's NixOS, nix-on-droid and nix-darwin configs";

  inputs = {
    # Nixpkgs
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    # Nix on Droid
    nix-on-droid = {
      url = "github:t184256/nix-on-droid/release-22.11";
      # url = "github:t184256/nix-on-droid/master";
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
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix User Repository
    nur = {
      url = "github:nix-community/NUR";
    };

    hardware = {
      url = "github:nixos/nixos-hardware";
    };

    nix-colors = {
      url = "github:misterio77/nix-colors";
    };

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
      inputs.zig-overlay.follows = "zig-overlay";
    };

    wired = {
      url = "github:Toqozz/wired-notify";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , nix-on-droid
    , nix-darwin
    , home-manager
    , hardware
    , nix-colors
    , neovim-nightly-overlay
    , zig-overlay
    , zls-overlay
    , wired
    , ...
    } @ inputs:
    let
      inherit (self) outputs;
      util = import ./util { inherit inputs outputs; };
    in rec {
      # Packages (`nix build`)
      packages = util.forEachPkgs (pkgs:
        import ./pkgs { inherit pkgs; }
      );

      # Apps (`nix run`)
      apps = util.forEachPkgs (pkgs:
        import ./apps { inherit pkgs; }
      );

      # Dev Shells (`nix develop`)
      devShells = util.forEachPkgs (pkgs:
        import ./shells { inherit pkgs; }
      );

      # Formatter
      formatter = util.forEachPkgs (pkgs:
        pkgs.nixpkgs-fmt
      );

      # Templates
      templates = import ./templates { inherit inputs outputs; };

      # Overlays
      overlays = import ./overlays { inherit inputs outputs; };

      # Machines
      inherit (util)
        machines
        homeManagerMachines
        nixDarwinMachines
        nixOnDroidMachines
        nixosMachines;

      # Modules
      inherit (util)
        nixosModules
        nixOnDroidModules
        nixDarwinModules
        homeManagerModules;

      # Configurations
      nixosConfigurations = util.autoNixosConfigurations;
      nixOnDroidConfigurations = util.autoNixOnDroidConfigurations;
      darwinConfigurations = util.autoDarwinConfigurations;
      homeConfigurations = util.autoHomeConfigurations;
    };
}
