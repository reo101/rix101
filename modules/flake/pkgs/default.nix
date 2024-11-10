{ inputs, self, lib, config, ... }:

{
  imports = [
    (
      { lib
      , flake-parts-lib
      , ...
      }: flake-parts-lib.mkTransposedPerSystemModule {
        name = "pkgs";
        file = ./default.nix;
        option = lib.mkOption {
          type = lib.types.unspecified;
        };
      }
    )
  ];

  perSystem = { pkgs, system, ... }: {
    _module.args.pkgs = let
      overlays = lib.attrValues self.overlays ++ [
        inputs.neovim-nightly-overlay.overlays.default
        inputs.zig-overlay.overlays.default
        inputs.nix-topology.overlays.default
        inputs.wired.overlays.default
        # NOTE: nix-on-droid overlay (needed for `proot`)
        inputs.nix-on-droid.overlays.default
        # NOTE: for `oddlamma`'s modified `lib.nix`
        # TODO: fork and expose separately
        inputs.nixos-extra-modules.overlays.default
      ] ++ [
        # WARN: not including a `self.packages` overlay
        #       because it causes an infinite recursion
        # (_: _: (config.perSystem system).packages)
        # (_: _: self.packages.${system})
      ];
    in import inputs.nixpkgs {
      inherit system;
      overlays = overlays ++ [
        (_: _: {
          # NOTE: `nixpkgs-stable` -> `pkgs.nixpkgs.stable.*`
          nixpkgs = lib.pipe inputs [
            (lib.concatMapAttrs
              (name: input:
                if lib.hasPrefix "nixpkgs-" name then {
                  ${lib.removePrefix "nixpkgs-" name} = import input {
                    inherit system;
                    inherit overlays;
                  };
                } else {
                }))
          ];
        })
      ];
      config = {
        # TODO: per machine?
        allowUnfree = true;
      };
    };

    # NOTE: Export this custom `pkgs` instance (+ our packages)
    pkgs = pkgs.extend (_: _: self.packages.${system});
  };
}
