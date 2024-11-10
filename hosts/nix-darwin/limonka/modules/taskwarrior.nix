{ inputs, lib, pkgs, config, ... }:

{
  home.packages = with pkgs; [
    taskopen
  ];

  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
    colorTheme = "dark-green-256";
    config = builtins.extraBuiltins.rageImportEncrypted
      ["${inputs.self}/secrets/identities/age-yubikey-1-identity-9306892a.pub"]
      ./taskwarrior-config.nix.age;
  };
}
