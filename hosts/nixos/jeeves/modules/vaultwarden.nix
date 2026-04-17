{
  lib,
  pkgs,
  config,
  ...
}:

let
  domain = "vw.jeeves.reo101.xyz";
in
{
  age.secrets."vaultwarden.password" = {
    rekeyFile = lib.custom.repoSecret "home/jeeves/vaultwarden/password.age";
  };

  age.secrets."vaultwarden.secret" = {
    rekeyFile = lib.custom.repoSecret "home/jeeves/vaultwarden/secret.env.age";
    generator = {
      dependencies = {
        inherit (config.age.secrets) "vaultwarden.password";
      };
      # NOTE: as per <https://github.com/dani-garcia/vaultwarden/wiki/Enabling-admin-page#using-argon2>
      script =
        {
          pkgs,
          decrypt,
          deps,
          ...
        }:
        /* bash */ ''
          ${decrypt} ${lib.escapeShellArg deps."vaultwarden.password".file} \
            | ${lib.getExe pkgs.libargon2} "$(${lib.getExe pkgs.openssl} rand -base64 32)" -e -id -k 19456 -t 2 -p 1 \
            | xargs printf "ADMIN_TOKEN='%s'\n"
        '';
    };
  };

  rix101.vaultwarden = {
    enable = true;
    environmentFile = config.age.secrets."vaultwarden.secret".path;
    inherit domain;

    nginx = {
      useACMEHost = "jeeves.reo101.xyz";
    };
  };
}
