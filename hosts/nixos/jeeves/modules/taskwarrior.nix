{ inputs, lib, pkgs, config, ... }:
{
  services.taskchampion-sync-server = {
    enable = true;
    port = 10222;
  };

  services.nginx.virtualHosts."taskwarrior.jeeves.lan" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString config.services.taskchampion-sync-server.port}";
      proxyWebsockets = true;
    };
  };
}
