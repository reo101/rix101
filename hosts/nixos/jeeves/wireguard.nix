{ inputs, lib, pkgs, config, ... }:

let
  wireguard-interface = "wg0";
  wireguard-network-cidr = "10.100.0.0/24";
  wireguard-network-host-cidr = lib.net.cidr.hostCidr 1 wireguard-network-cidr;
  wireguard-network-gateway = lib.net.cidr.host 1 wireguard-network-cidr;
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
    rekeyFile = "${inputs.self}/secrets/master/home/jeeves/wireguard/key.age";
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
    # TODO: `vlan` or something to multiplex `eth0` and `wlan0` for this
    externalInterface = "eth0";
    internalInterfaces = [ wireguard-interface ];
  };

  # Open ports in the firewall
  networking.firewall = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 51820 ];
  };

  # Local DNS resolving, mainly for `jeeves.lan`
  services.coredns = {
    enable = true;
    package = pkgs.coredns;
    config = ''
      . {
        # NOTE: binding on wireguard only
        bind ${wireguard-network-gateway}

        # Handle jeeves.lan subdomains locally
        template IN A jeeves.lan {
          match (.*\.)?jeeves\.lan
          answer "{{ .Name }} 60 IN A ${wireguard-network-gateway}"
          fallthrough
        }

        # Forward everything to main router
        forward . 192.168.1.1 {
          policy sequential
          health_check 5s
        }

        # Enable logging for debugging
        log
        errors
        cache
      }
    '';
  };

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
                (lib.net.cidr.host
                  (i + 1)
                  wireguard-network-cidr)
              ];
            })
            [
              {
                Host = "cheetah";
                PublicKey = "HtTZHebAQqpQEkzzQGc+jf8PB7xIpG4tYilSzRpGsxo=";
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
      address = [
        # NOTE: `10.100.0.1/24`
        wireguard-network-host-cidr
      ];
      networkConfig = {
        IPMasquerade = "ipv4";
        IPv4Forwarding = true;
        IPv6Forwarding = true;
      };
    };
  };
}
