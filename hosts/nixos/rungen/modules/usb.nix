{ inputs, lib, pkgs, ... }:
{
  services.udev.packages = [
    pkgs.qmk-udev-rules
    pkgs.android-tools
    pkgs.logitech-udev-rules
  ];
}
