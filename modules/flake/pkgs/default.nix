{ inputs, self, lib, config, ... }:

{
  perSystem = { system, ... }: {
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
      ];
      config = {
        # TODO: per machine?
        allowUnfree = true;
      };
    };
  };
}
