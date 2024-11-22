{ config, lib, host, ... }: let
  inherit (lib) types;
in {
  options = {
    hostname = lib.mkOption {
      description = "Hostname of the machine";
      type = types.str;
      default = host;
    };
  };
}
