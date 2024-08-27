{ inputs, lib, pkgs, config, ... }:

let
  paperlessDomain = "paperless.jeeves.local";
in
{
  age.secrets."paperless.password" = {
    rekeyFile = "${inputs.self}/secrets/home/jeeves/paperless/password.age";
    # generator.script = "alnum";
    mode = "440";
    # NOTE: `passwordFile` needs to be read by the `paperless-scheduler` service, which is run as the user `config.services.paperless.user`
    #       See <https://github.com/NixOS/nixpkgs/blob/797f7dc49e0bc7fab4b57c021cdf68f595e47841/nixos/modules/services/misc/paperless.nix#L251-L254>
    group = config.services.paperless.user;
  };

  # NOTE: no need, since we're accessing it from `nginx`
  # networking.firewall.allowedTCPPorts = [
  #   config.services.paperless.port
  # ];

  services.paperless = {
    enable = true;
    passwordFile = config.age.secrets."paperless.password".path;
    address = "0.0.0.0";
    port = 28981;
    dataDir = "/data/paperless";
    consumptionDirIsPublic = true;
    settings = rec {
      PAPERLESS_ADMIN_USER = "jeeves";

      # TODO: kanidm and https
      PAPERLESS_URL = "http://${paperlessDomain}";
      PAPERLESS_ALLOWED_HOSTS = lib.concatStringsSep "," [
        # For `nginx`
        "127.0.0.1"
        paperlessDomain
      ];
      PAPERLESS_CORS_ALLOWED_HOSTS = lib.concatStringsSep "," [
        "http://${paperlessDomain}"
      ];

      PAPERLESS_CONSUMER_IGNORE_PATTERN = [
        ".DS_STORE/*"
        "desktop.ini"
      ];

      PAPERLESS_OCR_LANGUAGE = lib.concatStringsSep "+" [
        "bul"
        "eng"
      ];
      # NOTE: `skip` causes "CamScanner" footer to skip actual document `OCR`
      PAPERLESS_OCR_MODE = "redo";
      PAPERLESS_OCR_USER_ARGS = {
        optimize = 1;
        pdfa_image_compression = "lossless";
        invalidate_digital_signatures = true;
      };
      # HACK: remove
      PAPERLESS_AUTO_LOGIN_USERNAME = PAPERLESS_ADMIN_USER;
    };
  };

  services.nginx = {
    virtualHosts.${paperlessDomain} = {
      enableACME = false;
      forceSSL = false;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString config.services.paperless.port}";
        proxyWebsockets = true;
      };
    };
  };
}
