{ config, lib, ... }: let
  inherit (lib) types;
in {
  options = {
    system = lib.mkOption {
      description = "The `system` of the host";
      type = types.str;
    };
  };
}
