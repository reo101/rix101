{
  config,
  pkgs,
  lib,
  ...
}:
{
  # NOTE: See <https://github.com/atuinsh/atuin/issues/952>
  systemd.user.services.atuin-daemon = {
    Unit = {
      Description = "Atuin background daemon";
      After = [ "network.target" ];
    };

    Service = {
      ExecStart = "${lib.getExe pkgs.atuin} daemon";
      Restart = "on-failure";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
