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
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
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
      inputs.rust-overlay.follows = "rust-overlay";
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
    lib = config.lib // {
      # HACK: `lib.systems` must match the `nixpkgs` instance's platform records
      systems = prev.lib.systems;
      # HACK: old `nixpkgs` packages may reference maintainers missing from current `nixpkgs.lib`
      maintainers = prev.lib.maintainers // config.lib.maintainers;
    };
    custom = self.legacyPackages.${final.stdenv.hostPlatform.system};
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
          overlays =
            overlays
            ++ lib.optional (!(builtins.pathExists "${input}/lib/services/lib.nix")) (
              _: _: {
                # HACK: current Home Manager imports `pkgs.path + /lib/services/lib.nix`
                path = inputs.nixpkgs;
              }
            );
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
