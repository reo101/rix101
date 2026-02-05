{ inputs, lib, config, self, ... }:

{
  key = "rix101.modules.flake.lib";

  options = let
    inherit (lib)
      types
      ;
  in {
    lib = lib.mkOption {
      internal = true;
      type = types.unspecified;
      apply = lib-custom: let
        extensions = lib.composeManyExtensions ([
          # NOTE: expose custom functions both under:
          # - `lib.${thing}`
          # - `lib.custom.${thing}`
          (final: prev: lib-custom)
          (final: prev: { custom = lib-custom; })
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
  config.flake.lib = config.lib;
}
