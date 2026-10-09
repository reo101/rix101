{ lib, pkgs, config, ... }:
{
  services.atuin = {
    enable = true;
    package = pkgs.atuin;
    host = "127.0.0.1";
    port = 8888;
    openFirewall = false;
    openRegistration = false;
  };

  services.nginx.virtualHosts."atuin.jeeves.reo101.xyz" = {
    forceSSL = true;
    useACMEHost = "jeeves.reo101.xyz";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString config.services.atuin.port}";
    };
  };
}
