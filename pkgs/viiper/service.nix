# Non-module dependencies (`importApply`)
{ }:

# Service module
{
  lib,
  config,
  options,
  ...
}:
let
  inherit (lib) types;

  cfg = config.viiper;
in
{
  _class = "service";

  options.viiper = {
    package = lib.mkOption {
      type = types.package;
      description = "Package to use for VIIPER.";
      defaultText = "The viiper package that provided this module.";
    };

    usbAddress = lib.mkOption {
      type = types.str;
      description = "USB/IP server listen address.";
      default = ":3241";
    };

    apiPort = lib.mkOption {
      type = types.port;
      description = "VIIPER API server listen port.";
      default = 3242;
    };

    apiAddress = lib.mkOption {
      type = types.str;
      description = "VIIPER API server listen address.";
      default = ":${toString cfg.apiPort}";
      defaultText = ''":${toString config.viiper.apiPort}"'';
    };

    autoAttachLocalClient = lib.mkOption {
      type = types.bool;
      description = "Whether VIIPER should auto-attach created devices to the local USB/IP client.";
      default = true;
    };

    requireLocalhostAuth = lib.mkOption {
      type = types.bool;
      description = "Whether localhost clients must authenticate to the VIIPER API.";
      default = false;
    };

    logLevel = lib.mkOption {
      type = types.enum [
        "trace"
        "debug"
        "info"
        "warn"
        "error"
      ];
      description = "VIIPER log level.";
      default = "info";
    };

    extraArgs = lib.mkOption {
      type = types.listOf types.str;
      description = "Extra command-line arguments passed to `viiper server`.";
      default = [ ];
      example = [ "--connection-timeout=10s" ];
    };

    environment = lib.mkOption {
      type = types.attrsOf types.str;
      description = "Extra environment variables for the service.";
      default = { };
    };
  };

  config = {
    meta.maintainers = with lib.maintainers; [ reo101 ];

    process.argv = [
      (lib.getExe cfg.package)
      "server"
      "--usb.addr=${cfg.usbAddress}"
      "--api.addr=${cfg.apiAddress}"
      "--api.auto-attach-local-client=${lib.boolToString cfg.autoAttachLocalClient}"
      "--api.require-local-host-auth=${lib.boolToString cfg.requireLocalhostAuth}"
      "--log.level=${cfg.logLevel}"
    ]
    ++ cfg.extraArgs;
  }
  // lib.optionalAttrs (options ? systemd) {
    systemd.service = {
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = cfg.environment;

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 5;
        ConfigurationDirectory = "viiper";
      };
    };
  };
}
