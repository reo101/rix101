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
  homeCidr = "192.168.1.0/24";
in
{
  environment.systemPackages = [ pkgs.wireguard-tools ];

  age.secrets."wireguard.privateKey" = {
    mode = "077";
    owner = "systemd-network";
    group = "systemd-network";
    rekeyFile = lib.repoSecret "home/arthur/wireguard/key.age";
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
  };

  networking.useNetworkd = true;

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
        ListenPort = 51820;
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
      address = [ "${myIp}/32" ];
      dns = [ (lib.net.cidr.host 1 wgServer.cidr) ];
      domains = [ "~lan" ];
      routes = [
        { Destination = wgServer.cidr; }
        { Destination = homeCidr; }
      ];
      linkConfig.ActivationPolicy = "down";
      linkConfig.RequiredForOnline = "no";
    };
  };
}
