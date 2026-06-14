{ config, lib, host, ... }: let
  inherit (lib) types;
in {
  options = {
    hostname = lib.mkOption {
      type = types.str;
      description = "Hostname of the machine";
      default = host;
    };
  };
}
