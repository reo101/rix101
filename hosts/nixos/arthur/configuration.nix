{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = [
    inputs.hardware.nixosModules.lenovo-thinkpad-t520
    inputs.hardware.nixosModules.common-gpu-nvidia-disable
    ./modules/disko
    ./modules/power.nix
    ./modules/users.nix
    ./modules/maintenance.nix
    ./modules/impermanence.nix
    ./modules/printers.nix
    ./modules/theming.nix
    ./modules/wireguard.nix
    ./modules/samba.nix
  ];

  networking.hostName = "arthur";

  boot = {
    initrd.availableKernelModules = [
      "ehci_pci"
      "ahci"
      "sd_mod"
      "sr_mod"
    ];
    kernelModules = [ "kvm-intel" ];
  };

  hardware.enableRedistributableFirmware = true;

  # Networking
  networking.networkmanager.enable = true;
  environment.persistence."/persist".directories = [
    # Saved `Wi-Fi` networks (passwords, `SSID`s, connection profiles)
    "/etc/NetworkManager/system-connections"
    # Bluetooth pairing keys
    "/var/lib/bluetooth"
  ];

  time.timeZone = "Europe/Sofia";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "bg_BG.UTF-8";
    LC_MONETARY = "bg_BG.UTF-8";
    LC_MEASUREMENT = "bg_BG.UTF-8";
  };

  # XFCE desktop
  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = true;
    desktopManager.xfce.enable = true;
  };

  # Audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  programs.firefox.enable = true;

  environment.systemPackages = [
    pkgs.git
    # Office Suite (`libreoffice-fresh` — `libreoffice` broken by nixpkgs#495635)
    pkgs.libreoffice-fresh
    # Archive manager
    pkgs.file-roller
    # PDF viewer
    pkgs.evince
    pkgs.gnome-disk-utility
    # Photo management
    pkgs.digikam
  ];

  system.stateVersion = "25.11";
}
