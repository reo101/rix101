{ lib, ... }:
let
  inherit (lib) types;
in
{
  options = {
    roles = lib.mkOption {
      description = "Named composition bundles to attach to this host";
      type = types.listOf types.str;
      default = [ ];
    };
  };
}
