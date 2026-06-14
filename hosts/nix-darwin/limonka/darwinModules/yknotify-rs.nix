{ inputs, lib, pkgs, ... }:

{
  imports = [
    inputs.yknotify-rs.darwinModules.default
  ];

  services.yknotify-rs.enable = true;
}
