{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ./modules/disko.nix
    ./modules/base.nix
    ./modules/vt.nix
    ./modules/battery.nix
    ./modules/binfmt.nix
    ./modules/hibernation.nix
    ./modules/nix.nix
    ./modules/sshd.nix
    ./modules/network.nix
    ./modules/hardware.nix
    ./modules/wayland.nix
    ./modules/graphics.nix
    ./modules/virtualisation.nix
    ./modules/usb.nix
    {
      imports = [
        ./modules/fingerprint-led.nix
      ];

      services.fingerprint-led = {
        enable = true;
        ledPath = "/sys/class/leds/chromeos:white:power";
        blinkInterval = 200;
      };
    }
    ./modules/tftp.nix
    ./modules/recording.nix
  ];

  time.timeZone = "Europe/Sofia";

  users.users.reo101.extraGroups = lib.mkAfter [ "users" ];

  networking.hostId = "a8997eee";
  system.stateVersion = "25.05";
}
