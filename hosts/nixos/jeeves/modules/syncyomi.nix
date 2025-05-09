{ lib, pkgs, config, ... }:
{
  services.syncyomi = {
    enable = true;
  };

  services.nginx = {
    virtualHosts."syncyomi.jeeves.lan" = {
      enableACME = false;
      forceSSL = false;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString config.services.syncyomi.port}";
        proxyWebsockets = true;
      };
    };
  };
}
