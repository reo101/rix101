{ inputs, ... }:
{
  imports = [
    inputs.flake-file.flakeModules.default
  ];

  flake-file = {
    description = "reo101's NixOS, nix-on-droid and nix-darwin configs";

    nixConfig = {
      commit-lockfile-summary = "chore(flake): update `flake.lock`";
      extra-substituters = [
        "https://rix101.cachix.org"
      ];
      extra-trusted-public-keys = [
        "rix101.cachix.org-1:2u9ZGi93zY3hJXQyoHkNBZpJK+GiXQyYf9J5TLzCpFY="
      ];
    };

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

      nixpkgs-trunk = {
        url = "github:nixos/nixpkgs/master";
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

      flake-file = {
        url = "github:vic/flake-file";
      };

      dream2nix = {
        url = "github:nix-community/dream2nix";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      crane = {
        url = "github:ipetkov/crane";
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
        inputs.systems.follows = "systems";
        # WARN: needs `nix` `2.30`+
        inputs.cl-nix-lite.inputs.systems.follows = "systems";
        inputs.cl-nix-lite.inputs.nixpkgs.follows = "nixpkgs";
        inputs.cl-nix-lite.inputs.flake-parts.follows = "flake-parts";
        inputs.cl-nix-lite.inputs.treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
        inputs.flake-utils.inputs.systems.follows = "systems";
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

      nix-lib-net = {
        url = "github:reo101/nix-lib-net";
      };

      yants = {
        url = "git+https://code.tvl.fyi/depot.git:/nix/yants.git";
        flake = false;
      };

      contracts = {
        url = "github:yvan-sraka/contracts";
        # WARN: is technically a flake, exposing the `default.nix` under `nixosModules.default`
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

      disko-zfs = {
        url = "github:numtide/disko-zfs";
        inputs.nixpkgs.follows = "nixpkgs";
        inputs.flake-parts.follows = "flake-parts";
        inputs.disko.follows = "disko";
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
        inputs.utils.inputs.systems.follows = "systems";
      };

      agenix = {
        url = "github:ryantm/agenix";
        inputs = {
          nixpkgs.follows = "nixpkgs";
          darwin.follows = "nix-darwin";
          home-manager.follows = "home-manager";
          systems.follows = "systems";
        };
      };

      ragenix = {
        url = "github:yaxitech/ragenix";
        inputs.crane.follows = "crane";
        inputs.agenix.follows = "agenix";
        inputs.nixpkgs.follows = "nixpkgs";
        inputs.flake-utils.inputs.systems.follows = "systems";
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
        inputs.systems.follows = "systems";
      };

      noctalia = {
        url = "github:noctalia-dev/noctalia-shell";
        inputs.nixpkgs.follows = "nixpkgs";
        inputs.noctalia-qs.inputs.systems.follows = "systems";
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
        inputs.systems.follows = "systems";
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
        inputs.systems.follows = "systems";
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
        inputs.systems.follows = "systems";
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
  };
}
