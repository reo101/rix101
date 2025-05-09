{ lib, pkgs, config, ... }:
{
  services.atuin = {
    enable = true;
    package = pkgs.atuin;
    host = "127.0.0.1";
    port = 8888;
    openFirewall = false;
    openRegistration = true;
  };

  services.nginx.virtualHosts."atuin.jeeves.lan" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString config.services.atuin.port}";
    };
  };
}
