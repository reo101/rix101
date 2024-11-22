{ config, lib, host, ... }: let
  inherit (lib) types;
in {
  options = {
    enable = lib.mkOption {
      description = "Whether to enable this host's configuration";
      type = types.bool;
      default = host != "__template__";
    };
  };
}
