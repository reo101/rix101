{ inputs, lib, pkgs, config, ... }:
{
  # Immich CLI
  services.localtimed.enable = true;
  services.geoclue2.enable = true;
  services.avahi.enable = true;
  time.timeZone = "Europe/Sofia";
  environment.systemPackages = with pkgs; [
    immich-go
  ];

  # Immich service
  services.nginx.virtualHosts."immich.jeeves.local" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString config.services.immich.port}";
      proxyWebsockets = true;
    };
  };

  services.immich = {
    enable = true;
    package = pkgs.immich;

    host = "0.0.0.0";
    port = 3001;
    # openFirewall = true;

    mediaLocation = "/data/immich";

    machine-learning = {
      enable = true;
      environment = {
      };
    };
    # secretsFile = "/run/secrets/immich";
    database = {
      enable = true;
      createDB = true;
    };
    redis = {
      enable = true;
    };
  };
}
