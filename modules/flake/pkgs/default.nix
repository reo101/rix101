{
  inputs,
  self,
  lib,
  config,
  ...
}:

{
  key = "rix101.modules.flake.pkgs";

  flake-file.inputs = {
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      # inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    zig-flake = {
      url = "github:silversquirl/zig-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zls = {
      url = "github:zigtools/zls";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.zig-flake.follows = "zig-flake";
    };

    wired = {
      url = "github:Toqozz/wired-notify";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  imports = [
    (
      {
        lib,
        flake-parts-lib,
        ...
      }:
      flake-parts-lib.mkTransposedPerSystemModule {
        name = "pkgs";
        file = ./default.nix;
        option = lib.mkOption {
          type = lib.types.unspecified;
        };
      }
    )
  ];

  flake.overlays.additions = final: prev: {
    custom = self.packages.${final.stdenv.hostPlatform.system};
  };

  perSystem =
    { pkgs, system, ... }:
    let
      nixpkgsConfig = {
        # TODO: per machine?
        allowUnfree = true;
      };
      mkNixpkgsInstance =
        input:
        import input {
          inherit system;
          inherit overlays;
          config = nixpkgsConfig;
        };
      # NOTE: `nixpkgs-stable` -> `pkgs.nixpkgs.stable.*`
      nixpkgsInstances = lib.pipe inputs [
        (lib.concatMapAttrs (
          name: input:
          lib.optionalAttrs (lib.hasPrefix "nixpkgs-" name) {
            ${lib.removePrefix "nixpkgs-" name} = mkNixpkgsInstance input;
          }
        ))
      ];
      overlays = lib.concatLists [
        # NOTE: overlays from flake inputs
        [
          inputs.neovim-nightly-overlay.overlays.default
          inputs.nix-topology.overlays.default
          inputs.wired.overlays.default
          # NOTE: nix-on-droid overlay (needed for `proot`)
          inputs.nix-on-droid.overlays.default
          # inputs.nix-lib-net.overlays.default
        ]

        # NOTE: overlays from flake outputs
        (lib.attrValues self.overlays)

        [
          (_: _: {
            nixpkgs = nixpkgsInstances;
          })
        ]
      ];
    in
    {
      _module.args.pkgs = mkNixpkgsInstance inputs.nixpkgs;

      # NOTE: Export this custom `pkgs` instance
      inherit pkgs;
    };
}
