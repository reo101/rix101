{ inputs, lib, pkgs, config, ... }:

{
  home.packages = with pkgs; [
    taskopen
  ];

  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
    colorTheme = "dark-green-256";
    config = lib.rageImportEncryptedOrDefault ./taskwarrior-config.nix.age {};
  };
}
