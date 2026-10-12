{ inputs, lib, pkgs, config, ... }:
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
    ./modules/tailscale.nix
    ./modules/hardware.nix
    ./modules/wayland.nix
    ./modules/steam.nix
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
    ./modules/septabee.nix
    ./modules/osu-touchpad.nix
  ];

  time.timeZone = "Europe/Sofia";

  age.secrets."koreader.zotero-api-key" = {
    owner = "reo101";
    mode = "0400";
    rekeyFile = lib.custom.repoSecret "home/jeeves/zotero/api-key.age";
  };
  age.secrets."koreader.zotero-webdav-password" = {
    owner = "reo101";
    mode = "0400";
    rekeyFile = lib.custom.repoSecret "home/jeeves/zotero/webdav-password.age";
  };

  users.users.reo101.extraGroups = lib.mkAfter [ "users" ];

  networking.hostId = "a8997eee";
  system.stateVersion = "25.05";
}
