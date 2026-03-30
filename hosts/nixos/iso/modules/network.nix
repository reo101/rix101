{
  inputs,
  config,
  lib,
  pkgs,
  meta,
  ...
}:

let
  jeeves-meta = inputs.self.nixosConfigurations.jeeves.meta;
  wgServer = jeeves-meta.wireguardServer;
  wireguard-interface = "wg0";
  myPeer = wgServer.peers.${meta.hostname};
  myIp = lib.net.cidr.host myPeer.hostIndex wgServer.cidr;
in
{
  environment.systemPackages = [
    pkgs.wireguard-tools
  ];

  age.secrets."wireguard.privateKey" = {
    rekeyFile = lib.custom.repoSecret "home/iso/wireguard/key.age";
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
      ''
        priv=$(${wg} genkey)
        ${wg} pubkey <<< "$priv" > ${lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")}
        echo "$priv"
      '';
    owner = "systemd-network";
    group = "systemd-network";
    mode = "0400";
  };

  systemd.network = {
    netdevs."50-${wireguard-interface}" = {
      netdevConfig = {
        Kind = "wireguard";
        Name = wireguard-interface;
        MTUBytes = "1300";
      };
      wireguardConfig = {
        PrivateKeyFile = config.age.secrets."wireguard.privateKey".path;
      };
      wireguardPeers = [
        {
          PublicKey = wgServer.publicKey;
          AllowedIPs = [ wgServer.cidr ];
          Endpoint = wgServer.endpoint;
          PersistentKeepalive = 25;
        }
      ];
    };

    networks."50-${wireguard-interface}" = {
      matchConfig.Name = wireguard-interface;
      address = [ myIp ];
      dns = [ wgServer.ip ];
      domains = [ "~lan" ];
      routes = [
        {
          Destination = wgServer.cidr;
        }
      ];
      linkConfig.RequiredForOnline = "no";
    };
  };

  systemd.services.iso-wireguard-refresh = {
    description = "Reload networkd after ISO WireGuard secret unlock";
    wantedBy = [ "multi-user.target" ];
    after = [
      "agenix-install-secrets.service"
      "systemd-networkd.service"
    ];
    requires = [
      "agenix-install-secrets.service"
      "systemd-networkd.service"
    ];
    path = [ pkgs.systemd ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -eu

      networkctl reload
      networkctl up ${wireguard-interface} || true
    '';
  };
}
