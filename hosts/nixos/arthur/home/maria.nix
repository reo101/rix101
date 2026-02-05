{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:

{
  imports = [
    ../homeModules/xfce.nix
    ../homeModules/office.nix
  ];

  home = {
    username = "maria";
    homeDirectory = "/home/maria";
    stateVersion = "25.11";
    sessionPath = [ "$HOME/.local/bin" ];
  };

  programs.home-manager.enable = true;
  programs.bash.enable = true;

  programs.firefox = {
    enable = true;
  };
}
