{ inputs, self, lib, config, ... }:

{
  perSystem = { pkgs, system, ... }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      # WARN: not including `self.packages` overlay
      #       because it causes an infinite recursion
      overlays = lib.attrValues self.overlays ++ [
        inputs.neovim-nightly-overlay.overlays.default
        inputs.zig-overlay.overlays.default
        inputs.nix-topology.overlays.default
        inputs.wired.overlays.default
        # nix-on-droid overlay (needed for `proot`)
        inputs.nix-on-droid.overlays.default
        # NOTE: for `oddlamma`'s modified `lib.nix`
        inputs.nixos-extra-modules.overlays.default
      ];
      config = {
        # TODO: per machine?
        allowUnfree = true;
      };
    };
  };
}
