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

  # Second netdev carrying ALL traffic (full tunnel); `wg0` carries only
  # private traffic (mesh + home LAN). Both share the key and tunnel IP, so
  # never bring both up at once — the server would see one peer flapping
  # between two ports. Toggle (networkd keeps both down at boot/rebuild):
  #   private: sudo networkctl down ${full-interface}; sudo networkctl up ${wireguard-interface}
  #   full:    sudo networkctl down ${wireguard-interface}; sudo networkctl up ${full-interface}
  #   off:     sudo networkctl down ${wireguard-interface} ${full-interface}
  full-interface = "wg-full";
  full-listen-port = 51821;
  # wg-quick-style full-tunnel policy table
  full-route-table = full-listen-port;
  homeCidr = "192.168.1.0/24";
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

  # networking.networkmanager = {
  #   enable = true;
  #   wifi.backend = "iwd";
  #   unmanaged = [
  #     "interface-name:eth0"
  #     "interface-name:${wireguard-interface}"
  #   ];
  # };

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
    config.systemd.network.netdevs."50-${full-interface}".wireguardConfig.ListenPort
    5353 # mDNS, cast discovery replies come from unicast source ports
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
            wgServer.cidr
            homeCidr
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
        {
          # Losing metric: at home the kernel-connected route wins, so this
          # never hijacks the real home LAN; away, this is the only route
          Destination = homeCidr;
          Metric = 2048;
        }
      ];
      linkConfig.ActivationPolicy = "down";
      linkConfig.RequiredForOnline = "no";
    };

    # Full tunnel: default routes live in a dedicated table and a policy rule
    # steers unmarked traffic there; wireguard's own outer packets carry the
    # firewall mark, skip the rule, and fall through to main (wlan0). This is
    # wg-quick's suppress-prefixlength trick without hardcoding the endpoint,
    # so it survives roaming between networks.
    netdevs."50-${full-interface}" = {
      netdevConfig = {
        Kind = "wireguard";
        Name = full-interface;
      };
      wireguardConfig = {
        PrivateKeyFile = config.age.secrets."wireguard.privateKey".path;
        ListenPort = full-listen-port;
        FirewallMark = full-route-table;
      };
      wireguardPeers = [
        {
          PublicKey = wgServer.publicKey;
          AllowedIPs = [
            wgServer.cidr
            "0.0.0.0/0"
            "::/0"
          ];
          Endpoint = wgServer.endpoint;
          PersistentKeepalive = 25;
        }
      ];
    };
    networks."50-${full-interface}" = {
      matchConfig.Name = full-interface;
      address = [ myIp ];
      dns = [ "${wgServer.ip}/32" ];
      # resolve everything through the tunnel in full mode
      domains = [ "~." ];
      routes = [
        {
          Destination = wgServer.cidr;
          Table = full-route-table;
        }
        {
          Destination = "0.0.0.0/0";
          Table = full-route-table;
        }
        {
          Destination = "::/0";
          Table = full-route-table;
        }
      ];
      routingPolicyRules = [
        {
          # unmarked v4 traffic -> full-tunnel table (netpath's priority 10000
          # rule still wins for VIP traffic)
          Priority = 10100;
          From = "0.0.0.0/0";
          FirewallMark = full-route-table;
          InvertRule = true;
          Table = full-route-table;
        }
        {
          Priority = 10100;
          From = "::/0";
          FirewallMark = full-route-table;
          InvertRule = true;
          Table = full-route-table;
        }
      ];
      linkConfig.ActivationPolicy = "down";
      linkConfig.RequiredForOnline = "no";
    };
  };
}
