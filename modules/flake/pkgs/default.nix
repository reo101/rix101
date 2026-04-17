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

    wired = {
      url = "github:Toqozz/wired-notify";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
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

  flake.overlays.additions =
    final: prev:
    let
      system = final.stdenv.hostPlatform.system;
      nixOnDroidArch =
        {
          aarch64-linux = "aarch64";
          x86_64-linux = "x86_64";
        }
        .${system} or null;
      nixOnDroidPackages = inputs.nix-on-droid.packages.${system} or { };
    in
    {
      custom = self.packages.${system};
      nixOnDroid = lib.optionalAttrs (nixOnDroidArch != null) {
        bootstrap = nixOnDroidPackages."bootstrap-${nixOnDroidArch}";
        bootstrapZip = nixOnDroidPackages."bootstrapZip-${nixOnDroidArch}";
        prootTermux = nixOnDroidPackages."prootTermux-${nixOnDroidArch}";
        tallocStatic = nixOnDroidPackages."tallocStatic-${nixOnDroidArch}";
      };
    };

  perSystem =
    { pkgs, system, ... }:
    {
      _module.args.pkgs =
        let
          overlays = lib.concatLists [
            # NOTE: overlays from flake inputs
            [
              inputs.neovim-nightly-overlay.overlays.default
              inputs.zig-overlay.overlays.default
              inputs.nix-topology.overlays.default
              inputs.wired.overlays.default
              # NOTE: nix-on-droid overlay (needed for `proot`)
              inputs.nix-on-droid.overlays.default
              # inputs.nix-lib-net.overlays.default
            ]

            # NOTE: overlays from flake outputs
            (lib.attrValues self.overlays)
          ];
        in
        import inputs.nixpkgs {
          inherit system;
          overlays = overlays ++ [
            (_: _: {
              # NOTE: `nixpkgs-stable` -> `pkgs.nixpkgs.stable.*`
              nixpkgs = lib.pipe inputs [
                (lib.concatMapAttrs (
                  name: input:
                  if lib.hasPrefix "nixpkgs-" name then
                    {
                      ${lib.removePrefix "nixpkgs-" name} = import input {
                        inherit system;
                        inherit overlays;
                      };
                    }
                  else
                    {
                    }
                ))
              ];
            })
          ];
          config = {
            # TODO: per machine?
            allowUnfree = true;
          };
        };

      # NOTE: Export this custom `pkgs` instance
      inherit pkgs;
    };
}
