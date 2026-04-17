{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
{
  rix101.taskchampionSyncServer = {
    enable = true;
    domain = "taskwarrior.jeeves.reo101.xyz";

    nginx = {
      useACMEHost = "jeeves.reo101.xyz";
    };
  };
}
