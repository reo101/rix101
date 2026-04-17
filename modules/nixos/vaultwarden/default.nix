{ lib, config, ... }:

let
  cfg = config.rix101.vaultwarden;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    optionalAttrs
    types
    ;
in
{
  options.rix101.vaultwarden = {
    enable = mkEnableOption "rix101 Vaultwarden service";

    environmentFile = mkOption {
      type = types.path;
      description = "Environment file passed to `services.vaultwarden.environmentFile`";
    };

    domain = mkOption {
      type = types.str;
      description = "Public Vaultwarden domain";
    };

    backupDir = mkOption {
      type = types.str;
      default = "/var/local/vaultwarden/backup";
      description = "Directory used for Vaultwarden backups";
    };

    signupsAllowed = mkOption {
      type = types.bool;
      default = true;
      description = "Whether new Vaultwarden signups are allowed";
    };

    rocketAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address bound by the Rocket web server";
    };

    rocketPort = mkOption {
      type = types.port;
      default = 8222;
      description = "Port bound by the Rocket web server";
    };

    rocketLog = mkOption {
      type = types.str;
      default = "critical";
      description = "Rocket log level";
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
    services.vaultwarden = {
      enable = true;
      dbBackend = "sqlite";
      inherit (cfg)
        environmentFile
        backupDir
        ;
      config = {
        DOMAIN = "https://${cfg.domain}";
        SIGNUPS_ALLOWED = cfg.signupsAllowed;

        ROCKET_ADDRESS = cfg.rocketAddress;
        ROCKET_PORT = cfg.rocketPort;
        ROCKET_LOG = cfg.rocketLog;
      };
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
          proxyPass = "http://127.0.0.1:${toString cfg.rocketPort}";
        };
      };
    };
  };

  meta.maintainers = with lib.maintainers; [ reo101 ];
}
