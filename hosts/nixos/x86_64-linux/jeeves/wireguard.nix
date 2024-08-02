{ inputs, lib, pkgs, config, ... }:
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
      script = { lib, pkgs, file, ... }: /* bash */ ''
        priv=$(${pkgs.wireguard-tools}/bin/wg genkey)
        ${pkgs.wireguard-tools}/bin/wg pubkey <<< "$priv" > ${lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")}
        echo "$priv"
      '';
    };
  };

  # Enable NAT
  networking.nat = {
    enable = true;
    enableIPv6 = true;
    externalInterface = "eth0";
    internalInterfaces = [ "wg0" ];
  };

  # Open ports in the firewall
  networking.firewall = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 51820 ];
  };

  systemd.network = {
    netdevs = {
      "50-wg0" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = "wg0";
          MTUBytes = "1300";
        };
        wireguardConfig = {
          PrivateKeyFile = config.age.secrets."wireguard.privateKey".path;
          ListenPort = 51820;
        };
        wireguardPeers =
          lib.mapAttrsToList
            (host: peerConfig: peerConfig)
            {
              cheetah = {
                PublicKey = "CFTGvBcly791ClwyS6PzTjmqztvYJW2eklR7it/QhxI=";
                AllowedIPs = [
                  "10.100.0.2/32"
                  "0.0.0.0/0"
                  # "::/0"
                ];
              };
              limonka = {
                PublicKey = "+x4cKc16KxhW/M3wv64FU1J0AkiLyXT5Oar6I1n1xk4=";
                AllowedIPs = [
                  "10.100.0.3/32"
                  "0.0.0.0/0"
                ];
              };
              peshoDjam = {
                PublicKey = "37QEe3Lsq5BTIzxqAh9z7clHYeaOaMH31oqi5YvAPBY=";
                AllowedIPs = [
                  "10.100.0.4/32"
                  "192.168.1.134/32"
                ];
              };
              s42 = {
                PublicKey = "pZF6M8TZ1FSBtTwFz4xzlMqwqRScEqgBfqHBk7ddixc=";
                AllowedIPs = [
                  "10.100.0.5/32"
                  "0.0.0.0/0"
                ];
              };
              a41 = {
                PublicKey = "/YEBfjDO+CfmYOKg9pO//ZAZQNutAS5z/Ggt2pX2gn0=";
                AllowedIPs = [
                  "10.100.0.6/32"
                  "0.0.0.0/0"
                ];
              };
              t410 = {
                PublicKey = "YSTgtHXcvbCwYrnBCNujsTkLy+umVZWLGECtV88NIW0=";
                AllowedIPs = [
                  "10.100.0.7/32"
                  "0.0.0.0/0"
                ];
              };
            };
      };
    };

    networks.wg0 = {
      matchConfig.Name = "wg0";
      address = [ "10.100.0.1/24" ];
      networkConfig = {
        IPMasquerade = "ipv4";
        IPv4Forwarding = true;
        IPv6Forwarding = true;
      };
    };
  };
}
