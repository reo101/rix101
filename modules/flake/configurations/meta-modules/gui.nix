{ config, lib, ... }: let
  inherit (lib) types;
in {
  options = {
    gui = lib.mkOption {
      description = "Enable GUI features";
      type = types.bool;
      default = false;
    };
  };
}
