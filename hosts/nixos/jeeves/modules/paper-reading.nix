{
  config,
  lib,
  pkgs,
  ...
}:

let
  zoteroWebdavDomain = "zotero-files.jeeves.reo101.xyz";
  koreaderSyncDomain = "kosync.jeeves.reo101.xyz";
  wireguardListen = [
    {
      addr = "192.168.1.210";
      port = 8443;
      ssl = true;
    }
  ];
  zoteroWebdavDataDir = "/data/zotero-webdav";
  koreaderSyncDataDir = "/data/.state/koreader-sync";
  zoteroWebdavPassword = config.age.secrets."zotero-webdav.password";
  zoteroWebdavService = pkgs.writeShellScript "zotero-webdav" ''
    IFS= read -r RCLONE_PASS < "$CREDENTIALS_DIRECTORY/webdav-password"
    export RCLONE_PASS
    exec ${lib.getExe pkgs.rclone} serve webdav ${zoteroWebdavDataDir} \
      --addr 127.0.0.1:8765 \
      --user zotero
  '';
in
{
  age.secrets."zotero-webdav.password" = {
    rekeyFile = lib.custom.repoSecret "home/jeeves/zotero/webdav-password.age";
    generator.script = "alnum";
    mode = "0400";
  };

  users.users.zotero-webdav = {
    isSystemUser = true;
    group = "zotero-webdav";
  };
  users.groups.zotero-webdav = { };

  systemd.tmpfiles.settings."paper-reading" = {
    ${zoteroWebdavDataDir}.d = {
      user = "zotero-webdav";
      group = "zotero-webdav";
      mode = "0750";
    };
    ${koreaderSyncDataDir}.d = {
      user = "root";
      group = "root";
      mode = "0700";
    };
  };

  systemd.services.zotero-webdav = {
    description = "Zotero attachment WebDAV storage";
    wantedBy = [ "multi-user.target" ];
    unitConfig.RequiresMountsFor = [ zoteroWebdavDataDir ];
    serviceConfig = {
      ExecStart = zoteroWebdavService;
      LoadCredential = "webdav-password:${zoteroWebdavPassword.path}";
      User = "zotero-webdav";
      Group = "zotero-webdav";
      Restart = "on-failure";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      ReadWritePaths = [ zoteroWebdavDataDir ];
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
    };
  };

  virtualisation.oci-containers.containers.koreader-sync = {
    image = "docker.io/koreader/kosync:v2.1.1";
    ports = [ "127.0.0.1:17200:17200" ];
    environment.ENABLE_USER_REGISTRATION = "true";
    volumes = [ "${koreaderSyncDataDir}/redis:/var/lib/redis" ];
  };

  systemd.tmpfiles.settings."paper-reading"."${koreaderSyncDataDir}/redis".d = {
    user = "root";
    group = "root";
    mode = "0700";
  };
  systemd.services.podman-koreader-sync.unitConfig.RequiresMountsFor = [
    "${koreaderSyncDataDir}/redis"
  ];

  services.nginx.virtualHosts = {
    ${zoteroWebdavDomain} = {
      forceSSL = true;
      useACMEHost = "jeeves.reo101.xyz";
      locations."/" = {
        proxyPass = "http://127.0.0.1:8765";
        extraConfig = ''
          client_max_body_size 0;
        '';
      };
    };

    ${koreaderSyncDomain} = {
      forceSSL = true;
      useACMEHost = "jeeves.reo101.xyz";
      locations."/" = {
        proxyPass = "http://127.0.0.1:17200";
      };
    };

    "wireguard-zotero-files" = {
      serverName = zoteroWebdavDomain;
      onlySSL = true;
      listen = wireguardListen;
      useACMEHost = "jeeves.reo101.xyz";
      locations."/" = {
        proxyPass = "http://127.0.0.1:8765";
        extraConfig = ''
          client_max_body_size 0;
        '';
      };
    };

    "wireguard-kosync" = {
      serverName = koreaderSyncDomain;
      onlySSL = true;
      listen = wireguardListen;
      useACMEHost = "jeeves.reo101.xyz";
      locations."/" = {
        proxyPass = "http://127.0.0.1:17200";
      };
    };
  };
}
