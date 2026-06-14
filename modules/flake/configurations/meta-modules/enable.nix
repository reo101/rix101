{ config, lib, host, ... }: let
  inherit (lib) types;
in {
  options = {
    enable = lib.mkOption {
      type = types.bool;
      description = "Whether to enable this host's configuration";
      default = host != "__template__";
    };
  };
}
