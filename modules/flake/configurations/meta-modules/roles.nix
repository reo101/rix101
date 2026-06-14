{ lib, ... }:

let
  inherit (lib) types;
in
{
  options = {
    roles = lib.mkOption {
      type = types.listOf types.str;
      description = "Named composition bundles to attach to this host";
      default = [ ];
    };
  };
}
