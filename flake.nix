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
      url = "github:nix-community/home-manager/release-22.11";
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
      # inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs.url = "github:nixos/nixpkgs?rev=fad51abd42ca17a60fc1d4cb9382e2d79ae31836";
    };

    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zls-overlay = {
      url = "github:zigtools/zls";
      inputs.nixpkgs.follows = "nixpkgs";
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
      # , hardware
      # , nix-colors
    , neovim-nightly-overlay
    , zig-overlay
    , zls-overlay
    , wired
    , ...
    } @ inputs:
    let
      inherit (self) outputs;
    in
    with (import ./lib { inherit inputs outputs; }); rec {
      # Packages (`nix build`)
      packages = forEachPkgs (pkgs:
        import ./pkgs { inherit pkgs; }
      );

      # Apps (`nix run`)
      apps = { };

      # Dev Shells (`nix develop`)
      devShells = forEachPkgs (pkgs:
        import ./shells { inherit pkgs; }
      );

      # Formatter
      formatter = forEachPkgs (pkgs:
        pkgs.nixpkgs-fmt
      );

      # Templates
      templates = import ./templates;

      # Overlays
      overlays = import ./overlays { inherit inputs outputs; };

      # Machines
      inherit machines;
      inherit homeManagerMachines;
      inherit nixDarwinMachines;
      inherit nixOnDroidMachines;
      inherit nixosMachines;

      # Modules
      inherit nixosModules;
      inherit nixOnDroidModules;
      inherit nixDarwinModules;
      inherit homeManagerModules;

      # Configurations
      nixosConfigurations = autoNixosConfigurations;
      nixOnDroidConfigurations = autoNixOnDroidConfigurations;
      darwinConfigurations = autoDarwinConfigurations;
      homeConfigurations = autoHomeConfigurations;
    };
}
