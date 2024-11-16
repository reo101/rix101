{ lib, pkgs, config, options, ... }:

{
  options = let
    inherit (lib) types;
  in {
    # HACK: think if this:
    # should be upstreamed
    # should be the other way around
    home-manager.users = lib.mkOption {
      type = types.attrsOf options.home-manager.config.type;
      default = {
        "nix-on-droid" = config.home-manager.config;
      };
    };
  };
}
