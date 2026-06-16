{ inputs, ... }:
{
  imports = [
    inputs.flake-file.flakeModules.default
  ];

  flake-file = {
    description = "reo101's NixOS, nix-on-droid and nix-darwin configs";

    nixConfig = {
      commit-lockfile-summary = "chore(flake): update `flake.lock`";
      extra-experimental-features = [
        "pipe-operators"
      ];
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

      nixpkgs-for-nod = {
        url = "github:NixOS/nixpkgs?rev=88d3861acdd3d2f0e361767018218e51810df8a1";
      };

      flake-parts = {
        url = "github:hercules-ci/flake-parts";
        inputs.nixpkgs-lib.follows = "nixpkgs";
      };

      flake-file = {
        url = "github:vic/flake-file";
      };

       flake-compat = {
         url = "github:edolstra/flake-compat";
         flake = false;
       };
 
       flake-utils = {
         url = "github:numtide/flake-utils";
         inputs.systems.follows = "systems";
       };
 
       gitignore = {
         url = "github:hercules-ci/gitignore.nix";
         inputs.nixpkgs.follows = "nixpkgs";
       };
 
       treefmt-nix = {
         url = "github:numtide/treefmt-nix";
         inputs.nixpkgs.follows = "nixpkgs";
       };
 
      steamlesslink = {
        url = "github:reo101/SteamlessLink";
        inputs.nixpkgs.follows = "nixpkgs";
        inputs.flake-parts.follows = "flake-parts";
        inputs.flake-file.follows = "flake-file";
        inputs.systems.follows = "systems";
        inputs.crane.follows = "crane";
        inputs.zig-flake.follows = "zig-flake";
        inputs.zls.follows = "zls";
      };

      crane = {
        url = "github:ipetkov/crane";
      };

      yknotify-rs = {
        url = "github:reo101/yknotify-rs";
        inputs.nixpkgs.follows = "nixpkgs";
        inputs.flake-parts.follows = "flake-parts";
      };

      impermanence = {
        url = "github:nix-community/impermanence";
        inputs.nixpkgs.follows = "nixpkgs";
        inputs.home-manager.follows = "home-manager";
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
        inputs.treefmt-nix.follows = "treefmt-nix";
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
        inputs.nixpkgs.follows = "nixpkgs";
      };

      nixos-apple-silicon = {
        url = "github:tpwrules/nixos-apple-silicon";
        inputs.nixpkgs.follows = "nixpkgs";
        inputs.flake-compat.follows = "flake-compat";
      };

      stylix = {
        url = "github:danth/stylix";
        inputs.nixpkgs.follows = "nixpkgs";
        inputs.flake-parts.follows = "flake-parts";
        inputs.systems.follows = "systems";
        inputs.nur.follows = "nur";
      };

      nix-colors = {
        url = "github:misterio77/nix-colors";
      };

      microvm = {
        url = "github:astro/microvm.nix";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      ida-pro = {
        url = "github:reo101/ida-pro-nix";
        inputs.nixpkgs.follows = "nixpkgs";
        inputs.flake-parts.follows = "flake-parts";
        inputs.flake-file.follows = "flake-file";
        inputs.systems.follows = "systems";
      };

      otzade = {
        url = "github:reo101/otzade";
        inputs.nixpkgs.follows = "nixpkgs";
        inputs.flake-parts.follows = "flake-parts";
        inputs.flake-file.follows = "flake-file";
        inputs.systems.follows = "systems";
        inputs.zig-flake.follows = "zig-flake";
        inputs.zls.follows = "zls";
      };
    };
  };
}
