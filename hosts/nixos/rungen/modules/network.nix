{
  inputs,
  lib,
  pkgs,
  config,
  meta,
  ...
}:

let
  jeeves-meta = inputs.self.nixosConfigurations.jeeves.meta;
  wgServer = jeeves-meta.wireguardServer;

  wireguard-interface = "wg0";
  myPeer = wgServer.peers.${meta.hostname};
  myIp = lib.net.cidr.host myPeer.hostIndex wgServer.cidr;
  listenPort = 51820;
in
{
  imports = [ inputs.self.nixosModules.netpath ];

  environment.systemPackages = [
    pkgs.iw
  ];

  networking.wireless = {
    iwd = {
      enable = true;

      settings = {
        General = {
          EnableNetworkConfiguration = false;
        };
        Wireless = {
          PowerSave = "off";
        };
        Rank = {
          BandModifier5GHz = 2;
          BandModifier6GHz = 3;
        };
      };
    };
  };
  networking.useNetworkd = true;

  services.netpath = {
    enable = true;
    profiles.home = {
      network = "192.168.1.0/24";
      gatewayHost = 1;
      virtualHost = 50;
      gatewayMac = "cc:28:aa:b3:1e:62";
    };
  };

  age.secrets."wireguard.privateKey" = {
    rekeyFile = lib.custom.repoSecret "home/rungen/wireguard/key.age";
    generator.script =
      {
        lib,
        pkgs,
        file,
        ...
      }:
      let
        wg = lib.getExe' pkgs.wireguard-tools "wg";
      in
      # bash
      ''
        priv=$(${wg} genkey)
        ${wg} pubkey <<< "$priv" > ${lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")}
        echo "$priv"
      '';
    owner = "systemd-network";
    group = "systemd-network";
    mode = "0400";
  };

  networking.firewall.allowedUDPPorts = [
    config.systemd.network.netdevs."50-${wireguard-interface}".wireguardConfig.ListenPort
  ];

  systemd.network = {
    enable = true;

    networks."10-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig.DHCP = "yes";
    };
    links."10-eth0" = {
      matchConfig.PermanentMACAddress = "9c:bf:0d:00:a1:af";
      linkConfig.Name = "eth0";
    };

    networks."15-wlan0" = {
      matchConfig.Name = "wlan0";
      networkConfig.DHCP = "yes";
    };
    links."15-wlan0" = {
      matchConfig.PermanentMACAddress = "04:68:74:dd:fe:ef";
      linkConfig.Name = "wlan0";
    };

    netdevs."50-${wireguard-interface}" = {
      netdevConfig = {
        Kind = "wireguard";
        Name = wireguard-interface;
      };
      wireguardConfig = {
        PrivateKeyFile = config.age.secrets."wireguard.privateKey".path;
        ListenPort = listenPort;
      };
      wireguardPeers = [
        {
          PublicKey = wgServer.publicKey;
          AllowedIPs = [
            # TODO: two netdevs with all/only private traffic
            # wgServer.cidr
            "0.0.0.0/0"
            "::/0"
          ];
          Endpoint = wgServer.endpoint;
          PersistentKeepalive = 25;
        }
      ];
    };
    networks."50-${wireguard-interface}" = {
      matchConfig.Name = wireguard-interface;
      address = [ myIp ];
      dns = [ "${wgServer.ip}/32" ];
      domains = [ "~lan" ];
      routes = [
        {
          Destination = wgServer.cidr;
        }
      ];
      linkConfig.ActivationPolicy = "down";
      linkConfig.RequiredForOnline = "no";
    };
  };
}
