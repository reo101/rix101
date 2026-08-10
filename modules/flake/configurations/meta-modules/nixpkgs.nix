{ lib, ... }:

{
  options = {
    nixpkgs = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = ''
        The nixpkgs package set used to build the host.
        - `null` selects `inputs.nixpkgs`
        - A raw instance name (key of `pkgs.nixpkgs`, i.e. any `nixpkgs-*` flake input) selects that instance
        - Anything else is treated as a nixpkgs-multiverse selector (e.g. a commit hash)
      '';
      default = null;
    };
  };
}
