{
  description = "reo101's NixOS, nix-on-droid and nix-darwin configs";

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, flake-parts-lib, ... }: {
      systems = import inputs.systems.outPath;

      # BUG: infinite recursion
      # imports = [
      #   ./modules/flake/modules
      # ] ++ inputs.self.flakeModules;

      imports = [
        ./modules/flake/lib
        ./modules/flake/lib-custom
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

        # Automatic packages, see `./modules/flake/packages/default.nix`
        packages.enable = true;

        # Automatic overlays, see `./modules/flake/overlays/default.nix`
        overlays.enable = true;

        # Automatic devShells, see `./modules/flake/shells/default.nix`
        devShells.enable = true;
      };

      perSystem = { lib, pkgs, system, ... }: {
        # Apps (`nix run`)
        apps = import ./apps { inherit pkgs; };

        # Formatter (`nix fmt`)
        formatter = pkgs.nixfmt;
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
    systems = {
      url = "github:nix-systems/default";
    };

    nix = {
      url = "github:DeterminateSystems/nix-src";
      # inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    # Nixpkgs
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    nixpkgs-stable = {
      url = "github:nixos/nixpkgs/nixos-24.05";
    };

    nixpkgs-staging = {
      url = "github:nixos/nixpkgs/staging";
    };

    nixpkgs-staging-next = {
      url = "github:nixos/nixpkgs/staging-next";
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
    dnshack = {
      url = "github:ettom/dnshack";
      flake = false;
    };

    # Nix Darwin
    nix-darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.cl-nix-lite.inputs.systems.follows = "systems";
      inputs.cl-nix-lite.inputs.nixpkgs.follows = "nixpkgs";
      inputs.cl-nix-lite.inputs.flake-parts.follows = "flake-parts";
      inputs.cl-nix-lite.inputs.treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    };

    yknotify-rs = {
      url = "github:reo101/yknotify-rs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
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
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nix-topology = {
      url = "github:oddlama/nix-topology";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    nix-lib-net = {
      url = "github:reo101/nix-lib-net";
    };

    yants = {
      url = "git+https://code.tvl.fyi/depot.git:/nix/yants.git";
      flake = false;
    };

    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix";
      flake = false;
    };

    alloc = {
      url = "github:Aleksanaa/alloc.nix";
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

    nixarr = {
      url = "github:nix-media-server/nixarr";
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
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix-rekey = {
      url = "github:oddlama/agenix-rekey";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    # Nix User Repository
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs-stable";
    };

    ukiyo = {
      url = "github:74k1/ukiyo";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hardware = {
      url = "github:nixos/nixos-hardware";
    };

    nixos-apple-silicon = {
      url = "github:tpwrules/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    nix-colors = {
      url = "github:misterio77/nix-colors";
    };

    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      # inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
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

    openwrt-imagebuilder = {
      url = "github:astro/nix-openwrt-imagebuilder";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    wired = {
      url = "github:Toqozz/wired-notify";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    commit-lockfile-summary = "chore(flake): update `flake.lock`";
  };
}
