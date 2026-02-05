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
      sync.server.url = "https://taskwarrior.jeeves.reo101.xyz";
      # HACK: set manually
      # sync.server.client_id = "";
      # sync.encryption_secret="";
    };
  };
}
