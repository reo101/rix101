{ lib, pkgs, config, ... }:
{
  environment.systemPackages = with pkgs; [
  ];

  # Networking
  age.secrets."home/wifi.env".file = ../../../../secrets/home/wifi.env.age;
  networking.wireless = {
    iwd.enable = true;
    environmentFile = config.age.secrets."home/wifi.env".path;
    networks = {
      home = {
        ssid = "@HOME_WIFI_SSID@";
        psk = "@HOME_WIFI_PSK@";
      };
    };
  };

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
}
