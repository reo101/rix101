{ wl-clipboard }:

{ lib, config, ... }:
let
  cfg = config.clipboard-url-cleaner;
in
{
  _class = "service";

  options.clipboard-url-cleaner.package = lib.mkOption {
    type = lib.types.package;
    description = "Clipboard URL cleaner package to run.";
    defaultText = "The clipboard-url-cleaner package that provided this module.";
  };

  config = {
    process.argv = [
      (lib.getExe' wl-clipboard "wl-paste")
      "--type"
      "text"
      "--watch"
      (lib.getExe cfg.package)
    ];

    systemd.service = {
      description = "Remove tracking parameters from Wayland clipboard URLs";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = lib.mkForce [ "graphical-session.target" ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 1;
      };
    };
  };
}
