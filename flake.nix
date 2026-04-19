# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  description = "reo101's NixOS, nix-on-droid and nix-darwin configs";

  outputs = inputs: import ./outputs.nix inputs;

  nixConfig = {
    commit-lockfile-summary = "chore(flake): update `flake.lock`";
    extra-experimental-features = [ "pipe-operators" ];
    extra-substituters = [
      "https://nix-on-droid.cachix.org"
      "https://rix101.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-on-droid.cachix.org-1:56snoMJTXmDRC1Ei24CmKoUqvHJ9XCp+nidK7qkMQrU="
      "rix101.cachix.org-1:2u9ZGi93zY3hJXQyoHkNBZpJK+GiXQyYf9J5TLzCpFY="
    ];
  };

  inputs = {
    agenix = {
      url = "github:ryantm/agenix";
      inputs = {
        darwin.follows = "nix-darwin";
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    agenix-rekey = {
      url = "github:oddlama/agenix-rekey";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
      };
    };
    alloc = {
      url = "github:Aleksanaa/alloc.nix";
      flake = false;
    };
    contracts = {
      url = "github:yvan-sraka/contracts";
      flake = false;
    };
    crane.url = "github:ipetkov/crane";
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        utils.inputs.systems.follows = "systems";
      };
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko-zfs = {
      url = "github:numtide/disko-zfs";
      inputs = {
        disko.follows = "disko";
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
      };
    };
    dnshack = {
      url = "github:ettom/dnshack";
      flake = false;
    };
    dream2nix = {
      url = "github:nix-community/dream2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-compat = {
      url = "github:inclyc/flake-compat";
      flake = false;
    };
    flake-file.url = "github:vic/flake-file";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    hardware.url = "github:nixos/nixos-hardware";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    htnl = {
      url = "github:molybdenumsoftware/htnl";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs-lib.follows = "nixpkgs";
      };
    };
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs = {
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
    };
    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix";
      flake = false;
    };
    jovian-nixos = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs = {
        cl-nix-lite.inputs = {
          flake-parts.follows = "flake-parts";
          nixpkgs.follows = "nixpkgs";
          systems.follows = "systems";
          treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
        };
        flake-utils.inputs.systems.follows = "systems";
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.flake-parts.follows = "flake-parts";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-stable.follows = "nixpkgs-stable";
      };
    };
    nix = {
      url = "github:DeterminateSystems/nix-src";
      inputs.flake-parts.follows = "flake-parts";
    };
    nix-colors.url = "github:misterio77/nix-colors";
    nix-darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-lib-net.url = "github:reo101/nix-lib-net";
    nix-monitored = {
      url = "github:ners/nix-monitored";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-on-droid = {
      url = "github:t184256/nix-on-droid";
      inputs = {
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
    };
    nix-topology = {
      url = "github:oddlama/nix-topology";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
      };
    };
    nixarr = {
      url = "github:nix-media-server/nixarr";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-apple-silicon = {
      url = "github:tpwrules/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-for-nod.url = "github:NixOS/nixpkgs?rev=88d3861acdd3d2f0e361767018218e51810df8a1";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-staging.url = "github:nixos/nixpkgs/staging";
    nixpkgs-staging-next.url = "github:nixos/nixpkgs/staging-next";
    nixpkgs-trunk.url = "github:nixos/nixpkgs/master";
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        noctalia-qs.inputs.systems.follows = "systems";
      };
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
      };
    };
    openwrt-imagebuilder = {
      url = "github:astro/nix-openwrt-imagebuilder";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs = {
        agenix.follows = "agenix";
        crane.follows = "crane";
        flake-utils.inputs.systems.follows = "systems";
        nixpkgs.follows = "nixpkgs";
      };
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    stylix = {
      url = "github:danth/stylix";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    systems.url = "github:nix-systems/default";
    ukiyo = {
      url = "github:74k1/ukiyo";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wired = {
      url = "github:Toqozz/wired-notify";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
      };
    };
    yants = {
      url = "git+https://code.tvl.fyi/depot.git:/nix/yants.git";
      flake = false;
    };
    yknotify-rs = {
      url = "github:reo101/yknotify-rs";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
      };
    };
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    zls-overlay = {
      url = "github:zigtools/zls";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        zig-overlay.follows = "zig-overlay";
      };
    };
  };
}
