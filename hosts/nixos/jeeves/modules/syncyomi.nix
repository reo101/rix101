{ pkgs, config, ... }:
{
  # NOTE: served through nginx, so no direct firewall opening is needed.
  system.services.syncyomi.imports = [ pkgs.custom.syncyomi.services.default ];

  services.nginx = {
    virtualHosts."syncyomi.jeeves.reo101.xyz" = {
      forceSSL = true;
      useACMEHost = "jeeves.reo101.xyz";
      locations."/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString config.system.services.syncyomi.syncyomi.port}";
        proxyWebsockets = true;
      };
    };
  };
}
