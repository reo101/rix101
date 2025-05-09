{ lib, pkgs, config, ... }:

let
  domain = "vw.jeeves.reo101.xyz";
in
{
  age.secrets."vaultwarden.password" = {
    rekeyFile = lib.repoSecret "home/jeeves/vaultwarden/password.age";
  };

  age.secrets."vaultwarden.secret" = {
    rekeyFile = lib.repoSecret "home/jeeves/vaultwarden/secret.env.age";
    generator = {
      dependencies = {
        inherit (config.age.secrets) "vaultwarden-password";
      };
      # NOTE: as per <https://github.com/dani-garcia/vaultwarden/wiki/Enabling-admin-page#using-argon2>
      script = { pkgs, decrypt, deps, ... }: /* bash */ ''
        ${decrypt} ${lib.escapeShellArg deps."vaultwarden.password".file} \
          | ${lib.getExe pkgs.libargon2} "$(${lib.getExe pkgs.openssl} rand -base64 32)" -e -id -k 19456 -t 2 -p 1 \
          | xargs printf "ADMIN_TOKEN='%s'\n"
      '';
    };
  };

  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    environmentFile = config.age.secrets."vaultwarden.secret".path;
    backupDir = "/var/local/vaultwarden/backup";
    config = {
      # Refer to https://github.com/dani-garcia/vaultwarden/blob/main/.env.template
      DOMAIN = "https://${domain}";
      SIGNUPS_ALLOWED = true;

      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      ROCKET_LOG = "critical";
    };
  };

  services.nginx = {
    virtualHosts."${domain}" = {
      forceSSL = true;
      # WARN: ACME is enabled for the whole `jeeves` subdomain
      # enableACME = true;
      useACMEHost = "jeeves.reo101.xyz";
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";
      };
    };
  };
}
