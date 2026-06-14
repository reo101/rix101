# Non-module dependencies (`importApply`)
{
  formats,
  writeShellScript,
  util-linux,
}:

# Service module
{
  lib,
  config,
  options,
  ...
}:
let
  inherit (lib)
    types
    ;

  cfg = config.syncyomi;
  defaultDataDir = "/var/lib/syncyomi";
  tomlFormat = formats.toml { };
  generatedConfig = tomlFormat.generate "syncyomi-initial-config.toml" cfg.config;
  ensureConfigScript = writeShellScript "syncyomi-ensure-config" ''
    set -eu

    CONFIG_DIR=${lib.escapeShellArg cfg.configDir}
    CONFIG_FILE=${lib.escapeShellArg "${cfg.configDir}/config.toml"}
    GENERATED_CONFIG=${lib.escapeShellArg generatedConfig}

    mkdir -p "$CONFIG_DIR"

    if [ ! -s "$CONFIG_FILE" ]; then
      echo "Generating initial SyncYomi config at $CONFIG_FILE"

      install -m0640 "$GENERATED_CONFIG" "$CONFIG_FILE"

      SESSION_SECRET=$(${lib.getExe' util-linux "uuidgen"} | tr -d '\n')
      echo "sessionSecret = \"$SESSION_SECRET\"" >> "$CONFIG_FILE"
    fi
  '';
in
{
  _class = "service";

  options.syncyomi = {
    package = lib.mkOption {
      type = types.package;
      description = "Package to use for SyncYomi.";
      defaultText = "The syncyomi package that provided this module.";
    };

    dataDir = lib.mkOption {
      type = types.path;
      description = ''
        State directory where SyncYomi stores its data.

        When left at the default, the systemd unit manages it through
        `StateDirectory`.
      '';
      default = defaultDataDir;
      example = "/srv/syncyomi";
    };

    configDir = lib.mkOption {
      type = types.path;
      description = "Directory passed to `--config` (`SyncYomi` writes files here).";
      default = "${cfg.dataDir}/config";
    };

    config = lib.mkOption {
      type = tomlFormat.type;
      description = ''
        Full declarative configuration for SyncYomi.
        Written once to `${cfg.configDir}/config.toml` if it does not exist.

        The `server.port` is automatically set from `syncyomi.port`
        unless overridden here.
      '';
      default = { };
      apply =
        serviceConfig:
        lib.mkMerge [
          {
            server.port = lib.mkDefault cfg.port;
            checkForUpdates = lib.mkDefault false;
          }
          serviceConfig
        ];
    };

    user = lib.mkOption {
      type = types.nullOr types.str;
      description = ''
        User the service runs as.

        When left as `null`, the unit uses `DynamicUser`.
      '';
      default = null;
      example = "syncyomi";
    };

    group = lib.mkOption {
      type = types.nullOr types.str;
      description = ''
        Group the service runs as.

        When left as `null`, the unit uses `DynamicUser`.
      '';
      default = null;
      example = "syncyomi";
    };

    port = lib.mkOption {
      type = types.port;
      description = "TCP port SyncYomi listens on.";
      default = 8282;
    };

    extraArgs = lib.mkOption {
      type = types.listOf types.str;
      description = "Extra command-line arguments passed to SyncYomi.";
      default = [ ];
      example = [ "--log-level=debug" ];
    };

    environment = lib.mkOption {
      type = types.attrsOf types.str;
      description = "Extra environment variables for the service.";
      default = { };
    };
  };

  config = {
    meta.maintainers = with lib.maintainers; [ reo101 ];

    assertions = [
      {
        assertion = (cfg.user == null) == (cfg.group == null);
        message = "syncyomi: set both `syncyomi.user` and `syncyomi.group`, or neither to use DynamicUser.";
      }
    ];

    process.argv = [
      (lib.getExe cfg.package)
      "--config=${cfg.configDir}"
    ]
    ++ cfg.extraArgs;
  }
  // lib.optionalAttrs (options ? systemd) {
    systemd.service = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = cfg.environment;

      serviceConfig = {
        Type = "simple";
        WorkingDirectory = cfg.dataDir;
        ExecStartPre = [ ensureConfigScript ];
        Restart = "on-failure";
        RestartSec = 5;

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        PrivateDevices = true;
        ProtectSystem = "strict";
        ReadWritePaths = lib.unique [
          cfg.dataDir
          cfg.configDir
        ];
      }
      // lib.optionalAttrs (cfg.user == null) {
        DynamicUser = true;
      }
      // lib.optionalAttrs (cfg.user != null) {
        User = cfg.user;
        Group = cfg.group;
      }
      // lib.optionalAttrs (cfg.dataDir == defaultDataDir) {
        StateDirectory = "syncyomi";
      };
    };
  };
}
