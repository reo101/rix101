{
  lib,
  pkgs,
  config,
  ...
}:

with lib;
let
  cfg = config.rix101.jellyfin;
in
{
  imports = [
  ];

  options = {
    rix101.jellyfin = {
      enable = mkEnableOption "rix101 Jellyfin config";
      image = mkOption {
        type = types.strMatching ".+/.+:.+";
        description = ''
          The Docker image for Jellyfin
        '';
        default = "docker.io/jellyfin/jellyfin:latest";
        defaultText = "docker.io/jellyfin/jellyfin:latest";
      };
      volumes = mkOption {
        type = types.listOf (types.strMatching ".+:.+");
        description = ''
          The volumes the Jellyfin container should bind to
        '';
        default = [
          "/var/cache/jellyfin/config:/config"
          "/var/cache/jellyfin/cache:/cache"
          "/var/log/jellyfin:/log"
          "/media:/media:ro"
        ];
      };
      ports = mkOption {
        type = types.listOf (types.strMatching ".+:.+");
        description = ''
          The ports the Jellyfin container should bind to
        '';
        default = [
          "8096:8096"
        ];
      };
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers."jellyfin" = {
      autoStart = true;
      image = cfg.image;
      volumes = cfg.volumes;
      ports = cfg.ports;
      environment = {
        JELLYFIN_LOG_DIR = "/log";
      };
    };
  };

  meta = {
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
