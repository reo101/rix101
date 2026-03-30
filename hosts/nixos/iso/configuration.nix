{
  lib,
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [
    "${modulesPath}/installer/cd-dvd/iso-image.nix"
    "${modulesPath}/installer/cd-dvd/channel.nix"
    "${modulesPath}/profiles/clone-config.nix"
    "${modulesPath}/profiles/minimal.nix"
    ./modules/base.nix
    ./modules/bootstrap.nix
    ./modules/installer-media.nix
    ./modules/network.nix
    ./modules/storage.nix
    ./modules/vt.nix
  ];

  time.timeZone = "Europe/Sofia";

  networking = {
    useDHCP = false;
    useNetworkd = true;

    networkmanager.enable = lib.mkForce false;

    wireless.iwd = {
      enable = true;
      settings = {
        General.EnableNetworkConfiguration = true;
        DriverQuirks.DefaultInterface = "?*";
      };
    };
  };

  nix = {
    package = pkgs.nixVersions.latest;

    settings = {
      trusted-users = lib.mkForce [
        "root"
        "reo101"
      ];

      experimental-features = [
        "ca-derivations"
        "dynamic-derivations"
        "recursive-nix"
        "flakes"
        "nix-command"
        "auto-allocate-uids"
        "cgroups"
      ];

      auto-optimise-store = true;
    };
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users.root.initialHashedPassword = lib.mkForce "!";

  systemd.network = {
    enable = true;
    wait-online = {
      enable = false;
      anyInterface = true;
    };
    networks."20-wired" = {
      matchConfig.Type = "ether";
      networkConfig.DHCP = "yes";
      linkConfig.RequiredForOnline = "no";
    };
  };
  system.stateVersion = "26.05";
}
