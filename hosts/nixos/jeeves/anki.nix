{ inputs, lib, pkgs, config, ... }:

{
  age.secrets."anki.reo101" = {
    rekeyFile = "${inputs.self}/secrets/home/jeeves/anki/reo101.age";
    mode = "400";
  };

  services.anki-sync-server = {
    enable = true;
    package = pkgs.anki-sync-server;
    users = [
      {
        username = "reo101";
        passwordFile = config.age.secrets."anki.reo101".path;
      }
    ];
    address = "0.0.0.0";
    port = 27701;
  };

  services.nginx = {
    virtualHosts."anki.jeeves.local" = {
      enableACME = false;
      forceSSL = false;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString config.services.anki-sync-server.port}";
      };
    };
  };
}
