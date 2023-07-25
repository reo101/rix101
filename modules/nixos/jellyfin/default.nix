{ lib, pkgs, config, ... }:

with lib;
let
  cfg = config.reo101.jellyfin;
in
{
  imports = [
  ];

  options = {
    reo101.jellyfin = {
      enable = mkEnableOption "reo101 Jellyfin config";
      image = mkOption {
        type = types.strMatching ".+/.+:.+";
        default = "docker.io/jellyfin/jellyfin:latest";
        defaultText = "docker.io/jellyfin/jellyfin:latest";
        description = ''
          The Docker image for Jellyfin
        '';
      };
      volumes = mkOption {
        type = types.listOf (types.strMatching ".+:.+");
        default = [
          "/var/cache/jellyfin/config:/config"
          "/var/cache/jellyfin/cache:/cache"
          "/var/log/jellyfin:/log"
          "/media:/media:ro"
        ];
        description = ''
          The volumes the Jellyfin container should bind to
        '';
      };
      ports = mkOption {
        type = types.listOf (types.strMatching ".+:.+");
        default = [
          "8096:8096"
        ];
        description = ''
          The ports the Jellyfin container should bind to
        '';
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
