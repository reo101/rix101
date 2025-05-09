{ lib, pkgs, config, ... }:

let
  inherit (lib) types;

  cfg = config.services.syncyomi;
  tomlFormat = pkgs.formats.toml { };
in
{
  options.services.syncyomi = {
    enable = lib.mkEnableOption "the SyncYomi server";

    package = lib.mkPackageOption pkgs "syncyomi" { };

    dataDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/syncyomi";
      example = "/srv/syncyomi";
      description = ''
        State directory where `SyncYomi` stores its data.
        If left as default, systemd will manage it via `StateDirectory`.
      '';
    };

    configDir = lib.mkOption {
      type = types.path;
      default = "${cfg.dataDir}/config";
      description = "Directory passed to `--config` (`SyncYomi` writes files here).";
    };

    config = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      apply = c: lib.mkMerge [
        {
          # NOTE: Always inject the module-defined port
          #       unless the user explicitly sets it here too
          server.port = cfg.port;
          # NOTE: `Nix` managed the package and service, no need for update checks
          checkForUpdates = false;
        }
        c
      ];
      description = ''
        Full declarative configuration for SyncYomi.
        Written once to `${cfg.configDir}/config.toml` if it does not exist.

        The `server.port` is automatically set from `services.syncyomi.port`
        unless overridden here.
      '';
    };

    user = lib.mkOption {
      type = types.str;
      default = "syncyomi";
      description = "User the service runs as.";
    };

    group = lib.mkOption {
      type = types.str;
      default = "syncyomi";
      description = "Group the service runs as.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 8282;
      description = "TCP port to open in the firewall (if `openFirewall = true`).";
    };

    openFirewall = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Open the firewall for the configured port.";
    };

    extraArgs = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "--log-level=debug" ];
      description = "Extra command-line arguments passed to `SyncYomi`.";
    };

    environment = lib.mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Extra environment variables for the service.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
    };
    users.groups.${cfg.group} = { };

    # NOTE: Create dataDir + configDir with correct ownership & perms
    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0750 ${cfg.user} ${cfg.group} -"
      "d '${cfg.configDir}' 0750 ${cfg.user} ${cfg.group} -"
      "f '${cfg.configDir}/config.toml' 0640 ${cfg.user} ${cfg.group} -"
    ];

    # NOTE: Open firewall if requested
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    systemd.services.syncyomi = {
      description = "SyncYomi server";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;

        StateDirectory = lib.mkIf (cfg.dataDir == "/var/lib/syncyomi") "syncyomi";
        WorkingDirectory = cfg.dataDir;

        # NOTE: Override `config.toml` directly every time
        ExecStartPre = pkgs.writeShellScript "syncyomi-config-toml-generation" ''
          if [ ! -e ${lib.escapeShellArg "${cfg.configDir}/config.toml"} ]; then
            ${lib.getExe' pkgs.coreutils "install"} -m0640 -o ${cfg.user} -g ${cfg.group} \
              ${lib.escapeShellArg (tomlFormat.generate "syncyomi-initial-config.toml" cfg.config)} \
              ${lib.escapeShellArg "${cfg.configDir}/config.toml"}
            # Generate a random sessionSecret and append it
            ${lib.getExe' pkgs.util-linux "uuidgen"} >> ${cfg.configDir}/config.toml
          fi
        '';

        ExecStart = ''
          ${lib.getExe cfg.package} \
            --config=${lib.escapeShellArg cfg.configDir} \
            ${lib.escapeShellArgs cfg.extraArgs}
        '';

        Restart = "on-failure";
        RestartSec = 5;

        # NOTE: Hardening
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
        ReadWritePaths = [ cfg.dataDir ];
      };

      environment =
        { TZ = config.time.timeZone or "UTC"; }
        // cfg.environment;
    };
  };
}
