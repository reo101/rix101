{
  inputs,
  config,
  lib,
  ...
}:
let
  inherit (lib) types;
in
{
  options = {
    nixpkgs = lib.mkOption {
      description = ''
        The `nixpkgs` flake input from which a `pkgs` instance should be build for the host.
        - `null` means `inputs.nixpkgs`
        - `"abc"` means `inputs.nixpkgs-abc`
      '';
      type = lib.pipe inputs [
        lib.attrNames
        (lib.concatMap (
          input: lib.optional (lib.hasPrefix "nixpkgs-" input) (lib.removePrefix "nixpkgs-" input)
        ))
        types.enum
        types.nullOr
      ];
      default = null;
    };
  };
}
