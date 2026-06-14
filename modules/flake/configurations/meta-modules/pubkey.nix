{ config, lib, ... }:

let
  inherit (lib) types;
in
{
  options = {
    pubkey = lib.mkOption {
      type = types.nullOr types.str;
      description = "The host SSH key, used for encrypting agenix secrets";
      default = null;
    };
  };
}
