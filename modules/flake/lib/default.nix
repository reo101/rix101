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
      apply = lib': let
        extensions = lib.composeManyExtensions ([
          # (final: prev: {
          #   utils = lib';
          # })
          (final: prev: lib')
        ] ++ config.lib-overlays);
      in lib.extend extensions;
    };
    lib-overlays = lib.mkOption {
      type = types.listOf types.unspecified;
      default = [];
    };
  };

  # NOTE: expose flake's `lib` augmentations to everybody
  #       (including configurations, check <../configurations/default-generators.nix>)
  config._module.args.lib = config.lib;
}
