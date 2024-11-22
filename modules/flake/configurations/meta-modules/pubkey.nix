{ config, lib, ... }: let
  inherit (lib) types;
in {
  options = {
    pubkey = lib.mkOption {
      description = "The host SSH key, used for encrypting agenix secrets";
      type = types.nullOr types.str;
      default = null;
    };
  };
}
