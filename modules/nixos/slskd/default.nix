{ lib, config, ... }:

let
  cfg = config.rix101.slskd;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    optionalAttrs
    types
    ;
in
{
  options.rix101.slskd = {
    enable = mkEnableOption "rix101 slskd service";

    environmentFile = mkOption {
      type = types.path;
      description = "Environment file passed to `services.slskd.environmentFile`";
    };

    restartTriggerFiles = mkOption {
      type = types.listOf types.path;
      description = "Files that should trigger a `slskd` restart when they change";
      default = [ ];
    };

    domain = mkOption {
      type = types.str;
      description = "Public domain exposed by the built-in nginx integration";
    };

    dataDir = mkOption {
      type = types.str;
      description = "Base directory for large transfer payloads and downloads";
      default = "/var/lib/slskd-data";
    };

    downloadsDir = mkOption {
      type = types.str;
      description = "Directory for completed downloads";
      default = "${cfg.dataDir}/downloads";
    };

    incompleteDir = mkOption {
      type = types.str;
      description = "Directory for in-progress downloads";
      default = "${cfg.dataDir}/incomplete";
    };

    group = mkOption {
      type = types.str;
      description = "Primary group for the slskd service user";
      default = "media";
    };

    shares = mkOption {
      type = types.listOf types.str;
      description = "Directories shared with Soulseek peers";
      default = [ ];
    };

    description = mkOption {
      type = types.str;
      description = "Soulseek peer description reported by slskd";
      default = cfg.domain;
    };

    listenPort = mkOption {
      type = types.port;
      description = "Soulseek listen port";
      default = 50300;
    };

    openFirewall = mkOption {
      type = types.bool;
      description = "Whether to open the upstream module's firewall rules";
      default = true;
    };

    umask = mkOption {
      type = types.str;
      description = "UMask applied to the slskd service";
      default = "0002";
    };

    nginx = {
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
    services.slskd = {
      enable = true;
      inherit (cfg)
        environmentFile
        group
        openFirewall
        domain
        ;

      nginx = {
        inherit (cfg.nginx)
          forceSSL
          ;
      }
      // optionalAttrs (cfg.nginx.useACMEHost != null) {
        inherit (cfg.nginx) useACMEHost;
      };

      settings = {
        directories = {
          downloads = cfg.downloadsDir;
          incomplete = cfg.incompleteDir;
        };

        shares.directories = cfg.shares;

        soulseek = {
          inherit (cfg)
            description
            ;
          listen_port = cfg.listenPort;
        };
      };
    };

    systemd.services.slskd.restartTriggers = cfg.restartTriggerFiles;
    systemd.services.slskd.serviceConfig.UMask = lib.mkForce cfg.umask;
    systemd.services.slskd.unitConfig.RequiresMountsFor = [ cfg.dataDir ];

    systemd.tmpfiles.settings."slskd" = {
      "${cfg.dataDir}".d = {
        user = config.services.slskd.user;
        group = config.services.slskd.group;
        mode = "0775";
      };
      "${cfg.downloadsDir}".d = {
        user = config.services.slskd.user;
        group = config.services.slskd.group;
        mode = "0775";
      };
      "${cfg.incompleteDir}".d = {
        user = config.services.slskd.user;
        group = config.services.slskd.group;
        mode = "0775";
      };
    };
  };

  meta.maintainers = with lib.maintainers; [ reo101 ];
}
