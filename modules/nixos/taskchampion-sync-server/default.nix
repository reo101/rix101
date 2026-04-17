{ lib, config, ... }:

let
  cfg = config.rix101.taskchampionSyncServer;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    optionalAttrs
    types
    ;
in
{
  options.rix101.taskchampionSyncServer = {
    enable = mkEnableOption "rix101 Taskchampion sync server";

    port = mkOption {
      type = types.port;
      default = 10222;
      description = "Port for `services.taskchampion-sync-server`";
    };

    domain = mkOption {
      type = types.str;
      description = "Public domain to proxy through nginx";
    };

    nginx = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      forceSSL = mkOption {
        type = types.bool;
        default = true;
      };
      useACMEHost = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };
  };

  config = mkIf cfg.enable {
    services.taskchampion-sync-server = {
      enable = true;
      inherit (cfg) port;
    };

    services.nginx.virtualHosts = optionalAttrs cfg.nginx.enable {
      "${cfg.domain}" = {
        forceSSL = cfg.nginx.forceSSL;
      }
      // optionalAttrs (cfg.nginx.useACMEHost != null) {
        inherit (cfg.nginx) useACMEHost;
      }
      // {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${builtins.toString cfg.port}";
          proxyWebsockets = true;
        };
      };
    };
  };

  meta.maintainers = with lib.maintainers; [ reo101 ];
}
