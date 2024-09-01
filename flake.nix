{
  description = "reo101's NixOS, nix-on-droid and nix-darwin configs";

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, flake-parts-lib, ... }: {
      systems = [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      # BUG: infinite recursion
      # imports = [
      #   ./modules/flake/modules
      # ] ++ inputs.self.flakeModules;

      imports = [
        ./modules/flake/lib
        ./modules/flake/pkgs
        ./modules/flake/modules
        ./modules/flake/configurations
        ./modules/flake/agenix
        ./modules/flake/topology
        ./modules/flake/packages
        ./modules/flake/overlays
        ./modules/flake/shells
      ];

      auto = {
        # Automatic modules, see `./modules/flake/modules/default.nix`
        modules.enableAll = true;

        # Automatic configurations, see `./modules/flake/configurations/default.nix`
        configurations.enableAll = true;

        # Automatic packages, see `./modules/flake/packages/default/default.nix`
        packages.enable = true;

        # Automatic overlays, see `./modules/flake/overlays/default/default.nix`
        overlays.enable = true;

        # Automatic devShells, see `./modules/flake/shells/default/default.nix`
        devShells.enable = true;
      };

      perSystem = { lib, pkgs, system, ... }: {
        # Apps (`nix run`)
        apps = import ./apps { inherit pkgs; };

        # Formatter (`nix fmt`)
        formatter = pkgs.nixpkgs-fmt;
      };

      flake = {
        inherit (inputs) self;

        # Templates
        templates = import ./templates {
          inherit inputs;
        };
      };
    });

  inputs = {
    # Nixpkgs
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    dream2nix = {
      url = "github:nix-community/dream2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix on Droid
    nix-on-droid = {
      url = "github:t184256/nix-on-droid";
      # url = "github:t184256/nix-on-droid/master";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Nix Darwin
    nix-darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-app-util = {
      url = "github:hraban/mac-app-util";
    };

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-compat = {
      url = "github:inclyc/flake-compat";
      flake = false;
    };

    impermanence = {
      url = "github:nix-community/impermanence";
    };

    nix-topology = {
      url = "github:oddlama/nix-topology";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lib-net = {
      url = "https://gist.github.com/duairc/5c9bb3c922e5d501a1edb9e7b3b845ba/archive/3885f7cd9ed0a746a9d675da6f265d41e9fd6704.tar.gz";
      flake = false;
    };

    nix-monitored = {
      url = "github:ners/nix-monitored";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    jovian-nixos = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        darwin.follows = "nix-darwin";
        home-manager.follows = "home-manager";
      };
    };

    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs.agenix.follows = "agenix";
    };

    agenix-rekey = {
      url = "github:oddlama/agenix-rekey";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix User Repository
    nur = {
      url = "github:nix-community/NUR";
    };

    spicetify-nix = {
      url = "github:the-argus/spicetify-nix";
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
}
