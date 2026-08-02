{ inputs, lib, pkgs, ... }:
{
  services.udev.packages = [
    pkgs.qmk-udev-rules
    pkgs.android-tools
    pkgs.logitech-udev-rules
  ];

  services.udev.extraRules = ''
    # Allow video group to control backlight (on add and change events)
    ACTION=="add|change", SUBSYSTEM=="backlight", ENV{DEVNAME}=="/dev/null", ATTR{brightness}="*", GROUP="video", MODE="0664"
  '';
}
