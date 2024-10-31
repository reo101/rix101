{ inputs, lib, pkgs, config, ... }:

{
  services.stirling-pdf = {
    enable = true;
    package = pkgs.stirling-pdf;
    environment = {
      # NOTE: random
      SERVER_PORT = 49528;
      INSTALL_BOOK_AND_ADVANCED_HTML_OPS = "true";
    };
    environmentFiles = [];
  };

  services.nginx = {
    virtualHosts."pdf.jeeves.lan" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString config.services.stirling-pdf.environment.SERVER_PORT}";
      };
    };
  };
}
