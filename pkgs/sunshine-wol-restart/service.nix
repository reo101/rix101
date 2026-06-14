# Non-module dependencies (`importApply`)
{ }:

# Service module
{
  lib,
  config,
  options,
  ...
}:
let
  inherit (lib) types;
  cfg = config.sunshine-wol-restart;
in
{
  _class = "service";

  options.sunshine-wol-restart = {
    package = lib.mkOption {
      type = types.package;
      description = "Package to use for sunshine-wol-restart.";
      defaultText = "The sunshine-wol-restart package that provided this module.";
    };

    targetMac = lib.mkOption {
      type = types.str;
      description = "MAC address expected inside the WoL magic packet.";
      example = "04:7c:16:80:3c:2c";
    };

    listenAddress = lib.mkOption {
      type = types.str;
      description = "IPv4 address to bind.";
      default = "0.0.0.0";
    };

    port = lib.mkOption {
      type = types.port;
      description = "UDP port to listen on.";
      default = 9;
    };

    user = lib.mkOption {
      type = types.str;
      description = "User whose systemd `--user` services should be restarted.";
      default = "jeeves";
    };

    restartServices = lib.mkOption {
      type = types.listOf types.str;
      description = "User services restarted after a matching WoL packet.";
      default = [
        "sunshine.service"
        "sunshine-niri.service"
      ];
    };

    openFirewall = lib.mkOption {
      type = types.bool;
      description = "Open the listen UDP port in the NixOS firewall.";
      default = true;
    };
  };

  config = {
    meta.maintainers = with lib.maintainers; [ reo101 ];

    process.argv = [
      (lib.getExe cfg.package)
      cfg.targetMac
      cfg.listenAddress
      (toString cfg.port)
      cfg.user
    ]
    ++ cfg.restartServices;
  }
  // lib.optionalAttrs (options ? systemd) {
    systemd.service = {
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 5;

        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        PrivateUsers = false;
        ProtectSystem = "strict";
        ProtectHome = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_UNIX"
        ];
      };
    };
  }
  // lib.optionalAttrs (options ? networking) {
    networking.firewall.allowedUDPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
