{ inputs, lib, config, self, ... }:

{
  options = let
    inherit (lib)
      types
      ;
  in {
    lib = lib.mkOption {
      internal = true;
      type = types.unspecified;
    };
    lib-overlays = lib.mkOption {
      type = types.listOf types.unspecified;
      default = [];
    };
  };

  # NOTE: expose flake's `lib` augmentations to everybody
  #       (including configurations, check <../configurations/default-generators.nix>)
  config._module.args.lib = let
    # NOTE: using raw `lib` to avoid recursion
    overlay = lib.composeManyExtensions ([
      # (final: prev: {
      #   utils = config.lib;
      # })
      (final: prev: config.lib)
    ] ++ config.lib-overlays);
  in lib.extend overlay;
}
