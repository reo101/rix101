{
  inputs,
  lib,
  pkgs,
  config,
  meta,
  ...
}:

let
  wgServer = meta.wireguardServer;
  wireguard-interface = "wg0";
  wireguard-network-cidr = wgServer.cidr;
  wireguard-network-host-cidr = lib.net.cidr.hostCidr 1 wireguard-network-cidr;
  wireguard-network-gateway = lib.net.cidr.host 1 wireguard-network-cidr;
  restrictedPeers = lib.filterAttrs (_: peer: peer ? allowedTCPPorts) wgServer.peers;
  peerIP = peer: lib.net.cidr.host peer.hostIndex wireguard-network-cidr;
  peerFirewallRules =
    peer:
    lib.concatMapStringsSep "\n" (port: /* bash */ ''
      iptables -A INPUT -i ${wireguard-interface} -s ${peerIP peer} -p tcp --dport ${toString port} -j ACCEPT
    '') peer.allowedTCPPorts
    + /* bash */ ''
      iptables -A INPUT -i ${wireguard-interface} -s ${peerIP peer} -j DROP
    '';
  peerFirewallStopRules =
    peer:
    lib.concatMapStringsSep "\n" (port: /* bash */ ''
      iptables -D INPUT -i ${wireguard-interface} -s ${peerIP peer} -p tcp --dport ${toString port} -j ACCEPT 2>/dev/null || true
    '') peer.allowedTCPPorts
    + /* bash */ ''
      iptables -D INPUT -i ${wireguard-interface} -s ${peerIP peer} -j DROP 2>/dev/null || true
    '';
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
    rekeyFile = lib.custom.repoSecret "home/jeeves/wireguard/key.age";
    generator = {
      script =
        {
          lib,
          pkgs,
          file,
          ...
        }:
        let
          wg = lib.getExe' pkgs.wireguard-tools "wg";
        in
        /* bash */ ''
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
    allowedUDPPorts = [
      53
      51820
    ];

    # A peer with `allowedTCPPorts` is denied everything else before NixOS's
    # general firewall rules (which otherwise apply to every WireGuard peer).
    extraCommands = lib.concatMapAttrsStringSep "\n" (_: peer: peerFirewallRules peer) restrictedPeers;
    extraStopCommands = lib.concatMapAttrsStringSep "\n" (
      _: peer: peerFirewallStopRules peer
    ) restrictedPeers;
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
        wireguardPeers = lib.mapAttrsToList (_host: peer: {
          PublicKey = peer.publicKey;
          AllowedIPs = [
            (lib.net.cidr.host peer.hostIndex wireguard-network-cidr)
          ];
        }) wgServer.peers;
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
