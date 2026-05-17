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
      description = "Package to use for VIIPER.";
      defaultText = "The viiper package that provided this module.";
      type = types.package;
    };

    usbAddress = lib.mkOption {
      type = types.str;
      default = ":3241";
      description = "USB/IP server listen address.";
    };

    apiPort = lib.mkOption {
      type = types.port;
      default = 3242;
      description = "VIIPER API server listen port.";
    };

    apiAddress = lib.mkOption {
      type = types.str;
      default = ":${toString cfg.apiPort}";
      defaultText = ''":${toString config.viiper.apiPort}"'';
      description = "VIIPER API server listen address.";
    };

    autoAttachLocalClient = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether VIIPER should auto-attach created devices to the local USB/IP client.";
    };

    requireLocalhostAuth = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Whether localhost clients must authenticate to the VIIPER API.";
    };

    logLevel = lib.mkOption {
      type = types.enum [
        "trace"
        "debug"
        "info"
        "warn"
        "error"
      ];
      default = "info";
      description = "VIIPER log level.";
    };

    extraArgs = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "--connection-timeout=10s" ];
      description = "Extra command-line arguments passed to `viiper server`.";
    };

    environment = lib.mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Extra environment variables for the service.";
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
