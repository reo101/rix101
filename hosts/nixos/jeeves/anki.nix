{ inputs, lib, pkgs, config, ... }:

{
  age.secrets."anki.reo101" = {
    rekeyFile = lib.repoSecret "home/jeeves/anki/reo101.age";
    mode = "400";
  };

  services.anki-sync-server = {
    enable = true;
    package = pkgs.anki-sync-server;
    users = [
      {
        # username = "reo101";
        username = "pavel.atanasov2001@gmail.com";
        passwordFile = config.age.secrets."anki.reo101".path;
      }
    ];
    address = "0.0.0.0";
    port = 27701;
  };

  services.nginx = {
    virtualHosts."anki.jeeves.lan" = {
      enableACME = false;
      forceSSL = false;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString config.services.anki-sync-server.port}";
      };
    };
  };
}
