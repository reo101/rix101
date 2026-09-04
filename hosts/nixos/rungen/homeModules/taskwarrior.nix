{ inputs, lib, pkgs, config, ... }:

{
  home.packages = [
    pkgs.taskopen
  ];

  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
    colorTheme = "dark-green-256";
    config = {
      # DD/MM/YYYY for entry/display; typing just DD/MM also works (year defaults to current)
      dateformat = "d/m/Y";
      "dateformat.report" = "%d/%m/%Y";
      "dateformat.value" = "%d/%m/%Y";
      "dateformat.info" = "%d/%m/%Y %H:%M";
      "dateformat.holiday" = "%d/%m/%Y";
      sync.server.url = "https://taskwarrior.jeeves.reo101.xyz";
      # HACK: set manually
      # sync.server.client_id = "";
      # sync.encryption_secret="";
    };
  };
}
