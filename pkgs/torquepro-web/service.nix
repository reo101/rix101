# Non-module dependencies (`importApply`)
{
  coreutils,
  writeShellScript,
}:

# Service module
{
  lib,
  config,
  options,
  name,
  ...
}:
let
  inherit (lib) types;
  cfg = config.torquepro-web;
  defaultStateDir = "/var/lib/${name}";
  boolString = value: if value then "1" else "0";
  prepareState = writeShellScript "${name}-prepare-state" ''
    ${lib.getExe' coreutils "install"} -d -m0750 \
      -o ${lib.escapeShellArg cfg.user} \
      -g ${lib.escapeShellArg cfg.group} \
      ${lib.escapeShellArg cfg.stateDir}
    ${lib.getExe' coreutils "install"} -d -m0700 \
      -o ${lib.escapeShellArg cfg.user} \
      -g ${lib.escapeShellArg cfg.group} \
      ${lib.escapeShellArg "${cfg.stateDir}/sessions"}
  '';
in
{
  _class = "service";

  options.torquepro-web = {
    package = lib.mkOption {
      type = types.package;
      description = "Torque Pro Web package to serve.";
      defaultText = "The torquepro-web package that provided this module.";
    };

    user = lib.mkOption {
      type = types.str;
      default = name;
      description = "Unix user used by the PHP-FPM pool.";
    };

    group = lib.mkOption {
      type = types.str;
      default = name;
      description = "Unix group used by the PHP-FPM pool.";
    };

    stateDir = lib.mkOption {
      type = types.path;
      default = defaultStateDir;
      description = "State directory containing PHP sessions.";
    };

    socket = lib.mkOption {
      type = types.path;
      default = "/run/php-fpm/${name}.sock";
      description = "PHP-FPM FastCGI socket.";
    };

    socketOwner = lib.mkOption {
      type = types.str;
      default = cfg.user;
      description = "Owner of the PHP-FPM socket.";
    };

    socketGroup = lib.mkOption {
      type = types.str;
      default = cfg.group;
      description = "Group of the PHP-FPM socket.";
    };

    database = {
      host = lib.mkOption {
        type = types.str;
        default = "localhost";
        description = "MariaDB or MySQL host. `localhost` uses its Unix socket.";
      };

      name = lib.mkOption {
        type = types.str;
        default = "torquepro";
        description = "Database name.";
      };

      user = lib.mkOption {
        type = types.str;
        default = cfg.user;
        description = "Database user.";
      };

      passwordFile = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional file containing the database password.";
      };
    };

    authentication = {
      user = lib.mkOption {
        type = types.str;
        description = "Dashboard login name.";
      };

      passwordFile = lib.mkOption {
        type = types.str;
        description = "File containing the dashboard password.";
      };

      deviceIdFile = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional newline-separated plain Torque device IDs allowed to upload.";
      };

      deviceIdHashFile = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional newline-separated MD5 Torque device IDs allowed to upload.";
      };
    };

    units = {
      sourceIsFahrenheit = lib.mkOption {
        type = types.bool;
        default = false;
      };
      useFahrenheit = lib.mkOption {
        type = types.bool;
        default = false;
      };
      sourceIsMiles = lib.mkOption {
        type = types.bool;
        default = false;
      };
      useMiles = lib.mkOption {
        type = types.bool;
        default = false;
      };
    };

    poolSettings = lib.mkOption {
      type = types.attrsOf (
        types.oneOf [
          types.str
          types.int
          types.bool
        ]
      );
      default = { };
      description = "Additional PHP-FPM pool settings.";
    };
  };

  config = {
    meta.maintainers = with lib.maintainers; [ reo101 ];

    assertions = [
      {
        assertion = cfg.authentication.deviceIdFile == null || cfg.authentication.deviceIdHashFile == null;
        message = "torquepro-web: set at most one of authentication.deviceIdFile and authentication.deviceIdHashFile.";
      }
    ];

    php-fpm.settings.${name} = {
      user = cfg.user;
      group = cfg.group;
      listen = cfg.socket;
      "listen.owner" = cfg.socketOwner;
      "listen.group" = cfg.socketGroup;
      "listen.mode" = "0660";
      pm = "ondemand";
      "pm.max_children" = 5;
      "pm.process_idle_timeout" = "10s";
      "pm.max_requests" = 500;
      "catch_workers_output" = true;
      "php_admin_flag[display_errors]" = "Off";
      "php_admin_flag[display_startup_errors]" = "Off";
      "php_admin_flag[log_errors]" = "On";
      "php_admin_value[error_reporting]" = "E_ALL";
      "php_admin_value[session.save_path]" = "${cfg.stateDir}/sessions";
      "env[TORQUEPRO_DB_HOST]" = cfg.database.host;
      "env[TORQUEPRO_DB_NAME]" = cfg.database.name;
      "env[TORQUEPRO_DB_USER]" = cfg.database.user;
      "env[TORQUEPRO_AUTH_USER]" = cfg.authentication.user;
      "env[TORQUEPRO_AUTH_PASSWORD_FILE]" = cfg.authentication.passwordFile;
      "env[TORQUEPRO_SOURCE_IS_FAHRENHEIT]" = boolString cfg.units.sourceIsFahrenheit;
      "env[TORQUEPRO_USE_FAHRENHEIT]" = boolString cfg.units.useFahrenheit;
      "env[TORQUEPRO_SOURCE_IS_MILES]" = boolString cfg.units.sourceIsMiles;
      "env[TORQUEPRO_USE_MILES]" = boolString cfg.units.useMiles;
    }
    // lib.optionalAttrs (cfg.database.passwordFile != null) {
      "env[TORQUEPRO_DB_PASSWORD_FILE]" = cfg.database.passwordFile;
    }
    // lib.optionalAttrs (cfg.authentication.deviceIdFile != null) {
      "env[TORQUEPRO_DEVICE_ID_FILE]" = cfg.authentication.deviceIdFile;
    }
    // lib.optionalAttrs (cfg.authentication.deviceIdHashFile != null) {
      "env[TORQUEPRO_DEVICE_ID_HASH_FILE]" = cfg.authentication.deviceIdHashFile;
    }
    // cfg.poolSettings;
  }
  // lib.optionalAttrs (options ? systemd) {
    systemd.service.serviceConfig = {
      ExecStartPre = [ prepareState ];
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ cfg.stateDir ];
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      UMask = "0077";
    };
  };
}
