{ lib, pkgs, config, ... }:
{
  services.syncyomi = {
    enable = true;
  };

  services.nginx = {
    virtualHosts."syncyomi.jeeves.reo101.xyz" = {
      forceSSL = true;
      useACMEHost = "jeeves.reo101.xyz";
      locations."/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString config.services.syncyomi.port}";
        proxyWebsockets = true;
      };
    };
  };
}
