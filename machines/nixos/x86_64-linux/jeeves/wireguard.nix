{ lib, pkgs, config, ... }:
{
  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];

  # NOTE: key generation
  # umask 077
  # wg genkey > private
  # wg pubkey < private > public

  # Server
  age.secrets."wireguard/server.private" = {
    file = ../../../../secrets/home/wireguard/server.private.age;
    mode = "077";
  };
  age.secrets."wireguard/server.public" = {
    file = ../../../../secrets/home/wireguard/server.public.age;
  };

  # Peers
  age.secrets."wireguard/cheetah.pub" = {
    file = ../../../../secrets/home/wireguard/cheetah.pub.age;
  };

  networking.firewall.allowedUDPPorts = [51820];
  systemd.network = {
    netdevs = {
      "50-wg0" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = "wg0";
          MTUBytes = "1300";
        };
        wireguardConfig = {
          PrivateKeyFile = config.age.secrets."wireguard/server.private".path;
          ListenPort = 51820;
        };
        wireguardPeers = [
          {
            # cheetah
            wireguardPeerConfig = {
              PublicKey = config.age.secrets."wireguard/cheetah.pub".path;
              AllowedIPs = [
                "0.0.0.0/0"
                # "::/0"
              ];
            };
          }
        ];
      };
    };
    networks.wg0 = {
      matchConfig.Name = "wg0";
      address = ["10.100.0.1/24"];
      networkConfig = {
        IPMasquerade = "ipv4";
        IPForward = true;
      };
    };
  };
}
