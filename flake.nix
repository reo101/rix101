{
  description = "reo101's NixOS, nix-on-droid and nix-darwin configs";

  inputs = {
    # Nixpkgs
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
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

  outputs =
    inputs:
    let
      inherit (inputs) self;
      inherit (self) outputs;
      util = import ./util { inherit inputs outputs; };
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, flake-parts-lib, ... }: {
      systems = [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      perSystem = { pkgs, lib, system, ... }: {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = lib.attrValues outputs.overlays;
          config = { };
        };

        # Packages (`nix build`)
        packages = import ./pkgs { inherit pkgs; };

        # Apps (`nix run`)
        apps = import ./apps { inherit pkgs; };

        # Dev Shells (`nix develop`)
        devShells = import ./shells { inherit pkgs inputs outputs; };

        # Formatter (`nix fmt`)
        formatter = pkgs.nixpkgs-fmt;

        # TODO: reseach `agenix-shell` <https://flake.parts/options/agenix-shell>
      };

      flake = {
        inherit self;

        # Templates
        templates = import ./templates {
          inherit inputs outputs;
        };

        # Overlays
        overlays = import ./overlays {
          inherit inputs outputs;
        };

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
          homeManagerModules
          flakeModules;

        # Configurations
        nixosConfigurations = util.autoNixosConfigurations;
        nixOnDroidConfigurations = util.autoNixOnDroidConfigurations;
        darwinConfigurations = util.autoDarwinConfigurations;
        homeConfigurations = util.autoHomeConfigurations;

        # Secrets
        agenix-rekey = inputs.agenix-rekey.configure {
          userFlake = self;
          nodes = {
            inherit (self.nixosConfigurations) jeeves;
          };
        };

        # Deploy.rs nodes
        deploy.nodes = util.deploy.autoNodes;
        checks = util.autoChecks;
      };
    });
}
