{ inputs, lib, pkgs, config, ... }:
{
  environment.systemPackages = with pkgs; [
  ];

  networking.extraHosts = ''
    127.0.0.1 jeeves.local
  '';

  # networking.nftables.enable = true;

  age.secrets."home.wifi.env" = {
    rekeyFile = "${inputs.self}/secrets/home/wifi/env.age";
  };
  networking.wireless = {
    iwd.enable = true;
    environmentFile = config.age.secrets."home.wifi.env".path;
    networks = {
      home = {
        ssid = "@HOME_WIFI_SSID@";
        psk = "@HOME_WIFI_PSK@";
      };
    };
  };

  networking.useNetworkd = true;
  systemd.network = {
    enable = true;
    wait-online = {
      enable = false;
      anyInterface = true;
      ignoredInterfaces = [
        "eth0"
      ];
    };

    networks."10-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig.DHCP = "yes";
      networkConfig.DHCPServer = "yes";
    };
    links."10-eth0" = {
      matchConfig.PermanentMACAddress = "04:7c:16:80:3c:2c";
      linkConfig.Name = "eth0"; # "enp8s0";
    };

    networks."15-wan0" = {
      matchConfig.Name = "wan0";
      networkConfig.DHCP = "yes";
    };
    links."15-wan0" = {
      matchConfig.PermanentMACAddress = "bc:f4:d4:40:5c:ed";
      linkConfig.Name = "wan0"; # "wlp15s0";
    };
  };

  # systemd.services.systemd-networkd.environment.SYSTEMD_LOG_LEVEL = "debug";
}
