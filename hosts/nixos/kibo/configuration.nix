{
  inputs,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    inputs.nixos-wsl.nixosModules.default
  ];

  networking.hostName = "kibo";

  wsl = {
    enable = true;
    defaultUser = "reo101";
    startMenuLaunchers = true;
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  programs.zsh.enable = true;

  users.users.reo101 = {
    isNormalUser = true;
    uid = 1000;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHBc0G9jbQYzwWqIzj504MrxsamFBzbISltpTrLaFUg1 cardno:31_228_281"
    ];
  };

  security.sudo-rs = {
    enable = true;
    extraRules = [
      {
        users = [ "reo101" ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };

  nix.settings.trusted-users = [
    "root"
    "reo101"
  ];

  time.timeZone = "Europe/Sofia";
  i18n.defaultLocale = "en_US.UTF-8";

  system.stateVersion = "26.05";
}
