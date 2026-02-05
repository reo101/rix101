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
  listenPort = 51820;

  connectionName = jeeves-meta.hostname;
  nmcli = lib.getExe' pkgs.networkmanager "nmcli";
in
{
  environment.systemPackages = [
    pkgs.wireguard-tools
  ];

  age.secrets."wireguard.privateKey" = {
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

  networking.firewall.allowedUDPPorts = [ listenPort ];

  # WARN: Not currently used — replaced by the systemd.network config below.
  # Kept for reference in case we want NM-native WireGuard toggling from the dock.
  systemd.services.wireguard-nm = {
    enable = false;
    description = "Set up WireGuard NetworkManager profile";
    after = [ "NetworkManager.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      umask 077
      key=$(cat ${config.age.secrets."wireguard.privateKey".path})

      cat > /run/NetworkManager/system-connections/wg-vpn.nmconnection <<INI
      [connection]
      id=${connectionName}
      type=wireguard
      interface-name=${wireguard-interface}
      autoconnect=false

      [wireguard]
      private-key=$key
      listen-port=${toString listenPort}

      [wireguard-peer.${wgServer.publicKey}]
      endpoint=${wgServer.endpoint}
      allowed-ips=${wgServer.cidr};${homeCidr};
      persistent-keepalive=25

      [ipv4]
      method=manual
      address1=${myIp}/32
      dns=${lib.net.cidr.host 1 wgServer.cidr};
      dns-search=~lan;
      route1=${wgServer.cidr}
      route2=${homeCidr}

      [ipv6]
      addr-gen-mode=default
      method=disabled
      INI

      ${nmcli} connection reload
    '';
  };

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
