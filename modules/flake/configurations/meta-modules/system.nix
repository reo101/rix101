{ config, lib, ... }:

let
  inherit (lib) types;
in
{
  options = {
    system = lib.mkOption {
      type = types.str;
      description = "The `system` of the host";
    };
  };
}
