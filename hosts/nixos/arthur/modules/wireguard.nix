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

  # WireGuard VPN to jeeves
  # Not auto-started: routing homeCidr through the tunnel conflicts
  # with being directly on that subnet at home.
  # Toggle with: systemctl start/stop wireguard-wg0
  networking.wireguard.interfaces.${wireguard-interface} = {
    ips = [ "${myIp}/32" ];
    listenPort = listenPort;
    privateKeyFile = config.age.secrets."wireguard.privateKey".path;

    peers = [
      {
        publicKey = wgServer.publicKey;
        allowedIPs = [
          wgServer.cidr
          homeCidr
        ];
        endpoint = wgServer.endpoint;
        persistentKeepalive = 25;
      }
    ];
  };

  # Don't auto-start — only useful when away from home
  systemd.services."wireguard-${wireguard-interface}".wantedBy = lib.mkForce [ ];
}
