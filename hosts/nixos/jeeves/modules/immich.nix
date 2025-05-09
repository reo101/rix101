{ inputs, lib, pkgs, config, ... }:
{
  # Immich CLI
  services.localtimed.enable = true;
  services.geoclue2.enable = true;
  services.avahi.enable = true;
  environment.systemPackages = with pkgs; [
    immich-go
  ];

  # Immich service
  services.nginx.virtualHosts."immich.jeeves.lan" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString config.services.immich.port}";
      # NOTE: https://immich.app/docs/administration/reverse-proxy/
      extraConfig = ''
        client_max_body_size 50G;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 43200s;
        proxy_send_timeout 43200s;
        send_timeout 43200s;
      '';
    };
  };

  services.immich = {
    enable = true;
    package = pkgs.immich;

    host = "0.0.0.0";
    port = 3001;
    openFirewall = true;

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
