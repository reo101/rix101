{
  inputs,
  config,
  pkgs,
  lib,
  meta,
  ...
}:

let
  jeeves-meta = inputs.self.nixosConfigurations.jeeves.meta;
  wgServer = jeeves-meta.wireguardServer;

  wireguard-interface = "wg0";
  myPeer = wgServer.peers.${meta.hostname};
  myIp = lib.net.cidr.host myPeer.hostIndex wgServer.cidr;
  homeCidr = "192.168.1.0/24";
  listenPort = 51820;
in
{
  environment.systemPackages = [
    pkgs.iw
  ];

  networking.wireless = {
    iwd = {
      enable = true;

      settings = {
        General = {
          EnableNetworkConfiguration = true;
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
            # homeCidr
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
        {
          Destination = homeCidr;
        }
      ];
      linkConfig.ActivationPolicy = "down";
      linkConfig.RequiredForOnline = "no";
    };
  };
}
