{ config, lib, ... }:

let
  inherit (lib) types;
in
{
  options = {
    gui = lib.mkOption {
      type = types.bool;
      description = "Enable GUI features";
      default = false;
    };
  };
}
