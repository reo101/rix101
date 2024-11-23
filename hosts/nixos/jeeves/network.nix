{ inputs, lib, pkgs, config, ... }:
{
  environment.systemPackages = with pkgs; [
  ];

  networking.extraHosts = ''
    # 127.0.0.1 jeeves.local
  '';

  # networking.nftables.enable = true;

  age.secrets."home.wifi.env" = {
    rekeyFile = "${inputs.self}/secrets/master/home/wifi/env.age";
  };
  networking.wireless = {
    iwd.enable = true;
    secretsFile = config.age.secrets."home.wifi.env".path;
    networks = {
      home = {
        ssid = "ext:HOME_WIFI_SSID";
        pskRaw = "ext:HOME_WIFI_PSK";
      };
    };
  };

  # TODO: `r8168` driver?

  networking.useNetworkd = true;
  systemd.network = {
    enable = true;
    wait-online = {
      enable = false;
      anyInterface = true;
      # ignoredInterfaces = [
      #   "eth0"
      # ];
    };

    networks."10-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig.DHCP = "yes";
    };
    links."10-eth0" = {
      matchConfig.PermanentMACAddress = "04:7c:16:80:3c:2c";
      linkConfig.Name = "eth0"; # "enp8s0";
    };

    networks."15-wlan0" = {
      matchConfig.Name = "wlan0";
      networkConfig.DHCP = "yes";
    };
    links."15-wlan0" = {
      matchConfig.PermanentMACAddress = "bc:f4:d4:40:5c:ed";
      linkConfig.Name = "wlan0"; # "wlp15s0";
    };
  };

  # systemd.services.systemd-networkd.environment.SYSTEMD_LOG_LEVEL = "debug";
}
