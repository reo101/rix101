{ inputs, outputs, lib, pkgs, config, ... }:
{
  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];

  # NOTE: key generation
  # umask 077
  # wg genkey > private
  # wg pubkey < private > public

  # Server
  age.secrets."wireguard.private" = {
    # file = ../../../../secrets/home/jeeves/wireguard/private.age;
    # file = "${inputs.self}/secrets/home/jeeves/wireguard/private.age";
    mode = "077";
    # FIXME: agenix-rekey
    rekeyFile = "${inputs.self}/secrets/home/jeeves/wireguard/private.age";
    # generator = {lib, pkgs, file, ...}: ''
    #   priv=$(${pkgs.wireguard-tools}/bin/wg genkey)
    #   ${pkgs.wireguard-tools}/bin/wg pubkey <<< "$priv" > ${lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")}
    #   echo "$priv"
    # '';
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
          PrivateKeyFile = config.age.secrets."wireguard.private".path;
          ListenPort = 51820;
        };
        wireguardPeers = [
          {
            # cheetah
            wireguardPeerConfig = {
              PublicKey = "CFTGvBcly791ClwyS6PzTjmqztvYJW2eklR7it/QhxI=";
              AllowedIPs = [
                "0.0.0.0/0"
                # "::/0"
              ];
            };
          }
          {
            # limonka
            wireguardPeerConfig = {
              PublicKey = "+x4cKc16KxhW/M3wv64FU1J0AkiLyXT5Oar6I1n1xk4=";
              AllowedIPs = [
                "0.0.0.0/0"
                # "192.168.1.0/24"
              ];
            };
          }
          {
            # s42
            wireguardPeerConfig = {
              PublicKey = "pZF6M8TZ1FSBtTwFz4xzlMqwqRScEqgBfqHBk7ddixc=";
              AllowedIPs = [
                "0.0.0.0/0"
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
