{
  lib,
  pkgs,
  config,
  ...
}:

let
  ACMEHost = "jeeves.reo101.xyz";
  domain = "slskd.${ACMEHost}";
  dataDir = "/data/media/slskd";
in
{
  age.secrets."slskd.env" = {
    rekeyFile = lib.custom.repoSecret "home/jeeves/slskd/env.age";
    generator.script =
      let
        stty = lib.getExe' pkgs.coreutils "stty";
        openssl = lib.getExe pkgs.openssl;
      in
      { pkgs, ... }:
      /* bash */ ''
        tty=/dev/tty
        if [[ ! -r "$tty" ]] || [[ ! -w "$tty" ]]; then
          echo "slskd.env generator requires an interactive terminal on /dev/tty" >&2
          exit 1
        fi

        printf 'Soulseek username: ' >"$tty"
        IFS= read -r slsk_username <"$tty"

        printf 'Soulseek password: ' >"$tty"
        old_tty="$(${stty} -g <"$tty")"
        trap '${stty} "$old_tty" <"$tty"' EXIT
        ${stty} -echo <"$tty"
        IFS= read -r slsk_password <"$tty"
        ${stty} "$old_tty" <"$tty"
        trap - EXIT
        printf '\n' >"$tty"

        slskd_api_key="$(${openssl} rand -hex 24)"
        web_password="$(${openssl} rand -base64 32)"
        slskd_api_key="''${slskd_api_key//$'\n'/}"
        web_password="''${web_password//$'\n'/}"

        printf '%s\n' \
          "SLSKD_SLSK_USERNAME=$slsk_username" \
          "SLSKD_SLSK_PASSWORD=$slsk_password" \
          "SLSKD_USERNAME=admin" \
          "SLSKD_PASSWORD=$web_password" \
          "SLSKD_API_KEY=$slskd_api_key"
      '';
  };

  services.slskd = {
    enable = true;
    environmentFile = config.age.secrets."slskd.env".path;
    group = "media";
    openFirewall = true;
    inherit domain;

    nginx = {
      forceSSL = true;
      useACMEHost = ACMEHost;
    };

    settings = {
      directories = {
        downloads = "${dataDir}/downloads";
        incomplete = "${dataDir}/incomplete";
      };

      shares.directories = [
        "/data/media/music"
      ];

      soulseek = {
        description = ACMEHost;
        listen_port = 50300;
      };
    };
  };

  # Keep completed downloads group-writable so `nixarr` services in the
  # shared `media` group can import and clean them up without ACL workarounds
  systemd.services.slskd.restartTriggers = [ config.age.secrets."slskd.env".file ];
  systemd.services.slskd.serviceConfig.UMask = lib.mkForce "0002";
  systemd.services.slskd.unitConfig.RequiresMountsFor = [ dataDir ];

  # The upstream module hardcodes the application directory under `/var/lib`,
  # so only the large transfer payloads move to `/data`
  systemd.tmpfiles.settings."slskd" = {
    "${dataDir}".d = {
      user = config.services.slskd.user;
      group = config.services.slskd.group;
      mode = "0775";
    };
    "${dataDir}/downloads".d = {
      user = config.services.slskd.user;
      group = config.services.slskd.group;
      mode = "0775";
    };
    "${dataDir}/incomplete".d = {
      user = config.services.slskd.user;
      group = config.services.slskd.group;
      mode = "0775";
    };
  };
}
