{ inputs, lib, pkgs, config, ... }:

let
  inherit (pkgs.lib) net;
  wireguard-interface = "wg0";
  wireguard-network-cidr = "10.100.0.0/24";
  wireguard-network-gateway = net.cidr.host 0 wireguard-network-cidr;
in
{
  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];

  # NOTE: key generation
  # umask 077
  # wg genkey > key
  # wg pubkey < key > key.pub

  # Server
  age.secrets."wireguard.privateKey" = {
    mode = "077";
    rekeyFile = "${inputs.self}/secrets/home/jeeves/wireguard/key.age";
    generator = {
      script = { lib, pkgs, file, ... }: let
        wg = lib.getExe' pkgs.wireguard-tools "wg";
      in /* bash */ ''
        priv=$(${wg} genkey)
        ${wg} pubkey <<< "$priv" > ${lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")}
        echo "$priv"
      '';
    };
  };

  # Enable NAT
  networking.nat = {
    enable = true;
    enableIPv6 = true;
    # TODO: `vlan` or something to multiplex `eth0` and `wan0` for this
    externalInterface = "eth0";
    internalInterfaces = [ wireguard-interface ];
  };

  # Open ports in the firewall
  networking.firewall = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 51820 ];
  };

  # Enable dnsmasq
  # FIXME: not working
  # NOTE: mainly for redirecting `wg0`'s DNS queries to `192.168.1.1`
  # services.resolved.enable = false;
  # services.dnsmasq = {
  #   enable = false;
  #   settings = {
  #     server = [
  #       "192.168.1.1"
  #       # "1.1.1.1"
  #     ];
  #     interface = [ wireguard-interface ];
  #     bind-interfaces = true;
  #     domain-needed = true;
  #     bogus-priv = true;
  #     no-resolv = true;
  #     address = [
  #       # NOTE: automatic `*.jeeves.local` subdomain handling
  #       "/jeeves.local/${wireguard-network-gateway}"
  #     ];
  #   };
  # };

  systemd.network = {
    netdevs = {
      "50-${wireguard-interface}" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = wireguard-interface;
          MTUBytes = "1300";
        };
        wireguardConfig = {
          PrivateKeyFile = config.age.secrets."wireguard.privateKey".path;
          ListenPort = 51820;
        };
        wireguardPeers =
          lib.imap1
            (i: peer: {
              inherit (peer) PublicKey;
              AllowedIPs = [
                (net.cidr.host
                  (i + 1)
                  wireguard-network-cidr)
              ];
            })
            [
              {
                Host = "cheetah";
                PublicKey = "CFTGvBcly791ClwyS6PzTjmqztvYJW2eklR7it/QhxI=";
              }
              {
                Host = "limonka";
                PublicKey = "+x4cKc16KxhW/M3wv64FU1J0AkiLyXT5Oar6I1n1xk4=";
              }
              {
                Host = "peshoDjam";
                PublicKey = "37QEe3Lsq5BTIzxqAh9z7clHYeaOaMH31oqi5YvAPBY=";
              }
              {
                Host = "s42";
                PublicKey = "pZF6M8TZ1FSBtTwFz4xzlMqwqRScEqgBfqHBk7ddixc=";
              }
              {
                Host = "a41";
                PublicKey = "/YEBfjDO+CfmYOKg9pO//ZAZQNutAS5z/Ggt2pX2gn0=";
              }
              {
                Host = "t410";
                PublicKey = "YSTgtHXcvbCwYrnBCNujsTkLy+umVZWLGECtV88NIW0=";
              }
            ];
      };
    };

    networks.${wireguard-interface} = {
      matchConfig.Name = wireguard-interface;
      address = [ wireguard-network-cidr ];
      networkConfig = {
        IPMasquerade = "ipv4";
        IPv4Forwarding = true;
        IPv6Forwarding = true;
      };
    };
  };
}
