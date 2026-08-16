{
  lib,
  pkgs,
  config,
  ...
}:
let
  name = "torquepro-web";
  user = name;
  domain = "torque.jeeves.reo101.xyz";
  package = pkgs.custom.torquepro-web;
  cfg = config.system.services.${name}.torquepro-web;
in
{
  age.secrets = {
    "${name}.auth-password" = {
      rekeyFile = lib.custom.repoSecret "home/jeeves/torquepro-web/auth-password.age";
      owner = user;
      mode = "0400";
      generator.script =
        { pkgs, ... }:
        /* bash */ ''
          ${lib.getExe pkgs.openssl} rand -base64 32
        '';
    };

    "${name}.device-id" = {
      rekeyFile = lib.custom.repoSecret "home/jeeves/torquepro-web/device-id.age";
      owner = user;
      mode = "0400";
    };
  };

  users = {
    groups.${user} = { };
    users.${user} = {
      isSystemUser = true;
      group = user;
    };
  };

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    ensureDatabases = [ cfg.database.name ];
    ensureUsers = [
      {
        name = cfg.database.user;
        ensurePermissions."${cfg.database.name}.*" = "ALL PRIVILEGES";
      }
    ];
  };

  systemd.services."${name}-database-setup" = {
    description = "Initialize the Torque Pro Web database";
    after = [ "mysql.service" ];
    requires = [ "mysql.service" ];
    before = [ "${name}.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = user;
      Group = user;
      RemainAfterExit = true;
    };
    script = ''
      if [[ "$(${config.services.mysql.package}/bin/mariadb \
        --batch --skip-column-names \
        ${lib.escapeShellArg cfg.database.name} \
        --execute "SHOW TABLES LIKE 'sessions'")" != sessions ]]; then
        ${config.services.mysql.package}/bin/mariadb \
          ${lib.escapeShellArg cfg.database.name} \
          < ${package.schema}
      fi
    '';
  };

  system.services.${name} = {
    imports = [ package.services.default ];

    torquepro-web = {
      socketOwner = config.services.nginx.user;
      socketGroup = config.services.nginx.group;
      authentication = {
        user = "reo101";
        passwordFile = config.age.secrets."${name}.auth-password".path;
        deviceIdFile = config.age.secrets."${name}.device-id".path;
      };
    };

    systemd.service = {
      after = [
        "mysql.service"
        "${name}-database-setup.service"
      ];
      requires = [
        "mysql.service"
        "${name}-database-setup.service"
      ];
    };
  };

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    useACMEHost = "jeeves.reo101.xyz";
    root = "${package}/share/torquepro-web";

    locations = {
      "/" = {
        index = "dashboard.php";
        tryFiles = "$uri $uri/ =404";
      };

      "~ \\.php$" = {
        tryFiles = "$uri =404";
        extraConfig = ''
          include ${pkgs.nginx}/conf/fastcgi.conf;
          fastcgi_pass unix:${cfg.socket};
        '';
      };

      "^~ /includes/".return = "404";
      "^~ /data/".return = "404";
      "^~ /docs/".return = "404";
      "= /backfill_sensor_names.php".return = "404";
      "= /migrate_saved_dashboards.php".return = "404";
      "= /parser.php".return = "404";
      "= /reprocess.php".return = "404";
      "~ \\.(?:csv|md|sql)$".return = "404";
    };
  };
}
