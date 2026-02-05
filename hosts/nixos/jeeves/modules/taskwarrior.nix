{ inputs, lib, pkgs, config, ... }:
{
  services.taskchampion-sync-server = {
    enable = true;
    port = 10222;
  };

  services.nginx.virtualHosts."taskwarrior.jeeves.reo101.xyz" = {
    forceSSL = true;
    useACMEHost = "jeeves.reo101.xyz";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString config.services.taskchampion-sync-server.port}";
      proxyWebsockets = true;
    };
  };
}
