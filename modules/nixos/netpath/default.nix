{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.services.netpath;

  profileType = types.submodule {
    options = {
      network = mkOption {
        type = types.net.cidrv4;
        description = "IPv4 network on which address handover is trusted";
        example = "192.168.1.0/24";
      };

      gatewayHost = mkOption {
        type = types.ints.unsigned;
        description = "Gateway host index within the network";
        default = 1;
      };

      virtualHost = mkOption {
        type = types.ints.unsigned;
        description = "Shared virtual host index within the network";
        example = 50;
      };

      gatewayMac = mkOption {
        type = types.net.mac;
        description = "Gateway MAC used to identify this trusted network";
      };

      paths = {
        ethernet = mkOption {
          type = types.coercedTo types.str lib.singleton (types.listOf types.str);
          description = "Ethernet interfaces eligible to carry the VIP";
          default = [ "eth0" ];
        };

        wifi = mkOption {
          type = types.coercedTo types.str lib.singleton (types.listOf types.str);
          description = "Wi-Fi interfaces eligible to carry the VIP";
          default = [ "wlan0" ];
        };
      };
    };
  };

  profiles = lib.mapAttrsToList (
    name: profile:
    let
      cidr = lib.net.cidr.canonicalize profile.network;
    in
    {
      inherit name cidr;
      gateway = lib.net.cidr.host profile.gatewayHost cidr;
      gateway_mac = profile.gatewayMac;
      vip = lib.net.cidr.host profile.virtualHost cidr;
      inherit (profile) paths;
    }
  ) cfg.profiles;

  netpathConfig = pkgs.writeText "netpath.json" (
    builtins.toJSON {
      routing = {
        inherit (cfg.routing) table priority probe;
        require_probe = cfg.routing.requireProbe;
      };
      inherit profiles;
    }
  );
in
{
  options.services.netpath = {
    enable = mkEnableOption "make-before-break IPv4 handover";

    package = lib.mkPackageOption pkgs.custom "netpath" { };

    profiles = mkOption {
      type = types.attrsOf profileType;
      description = "Trusted networks and their handover addresses";
      default = { };
    };

    routing = {
      table = mkOption {
        type = types.ints.unsigned;
        description = "Policy routing table owned by netpath";
        default = 100;
      };

      priority = mkOption {
        type = types.ints.unsigned;
        description = "Policy routing rule priority owned by netpath";
        default = 10000;
      };

      probe = mkOption {
        type = types.net.ipv4;
        description = "Address used to verify Internet reachability";
        default = "1.1.1.1";
      };

      requireProbe = mkOption {
        type = types.bool;
        description = "Abort a switch if the internet probe is unreachable; if false, only the LAN gateway is checked (LAN handover works through uplink outages)";
        default = false;
      };
    };

    reconcileInterval = mkOption {
      type = types.str;
      description = "Interval between active-path reconciliation runs";
      default = "5s";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.profiles != { };
        message = "services.netpath.profiles must contain at least one trusted network";
      }
    ]
    ++ lib.concatLists (lib.mapAttrsToList (
      name: profile:
      let
        capacity = lib.net.cidr.capacity profile.network;
      in
      [
        {
          assertion =
            profile.gatewayHost > 0
            && profile.gatewayHost < capacity - 1
            && profile.virtualHost > 0
            && profile.virtualHost < capacity - 1
            && profile.gatewayHost != profile.virtualHost;
          message = "services.netpath.profiles.${name} must use distinct, non-reserved host indices";
        }
        {
          assertion = (lib.intersectLists profile.paths.ethernet profile.paths.wifi) == [];
          message = "services.netpath.profiles.${name} roles must be disjoint (no interface in both ethernet and wifi)";
        }
      ]
    ) cfg.profiles);

    environment.systemPackages = [ cfg.package ];
    environment.etc."netpath.json".source = netpathConfig;

    networking.firewall.checkReversePath = "loose";

    boot.kernel.sysctl = {
      "net.ipv4.conf.all.arp_filter" = 1;
      "net.ipv4.conf.default.arp_filter" = 1;
      "net.ipv4.conf.all.arp_announce" = 2;
      "net.ipv4.conf.default.arp_announce" = 2;
    };

    systemd.network.config.networkConfig = {
      ManageForeignRoutes = false;
      ManageForeignRoutingPolicyRules = false;
    };

    systemd.services.netpath-init = {
      description = "Select the initial trusted-LAN path";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe cfg.package} auto";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    systemd.services.netpath-reconcile = {
      description = "Reconcile the active trusted-LAN path";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe cfg.package} reconcile";
      };
    };

    systemd.timers.netpath-reconcile = {
      description = "Periodically reconcile the active trusted-LAN path";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "10s";
        OnUnitActiveSec = cfg.reconcileInterval;
        Unit = "netpath-reconcile.service";
      };
    };
  };

  meta.maintainers = with lib.maintainers; [ reo101 ];
}
