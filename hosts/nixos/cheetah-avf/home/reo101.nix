{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:

{
  imports = [
    inputs.self.modules.home-manager.ida-pro
  ];

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    username = "reo101";
    homeDirectory = lib.mkForce "/home/${config.home.username}";
    stateVersion = "26.05";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # AVF runs a Wayland-only Niri session. nixos-avf still exports DISPLAY=:0,
  # which makes Home Manager's Xresources activation try `xrdb` against a
  # non-existent X server.
  stylix.targets.xresources.enable = false;

  home.packages = with pkgs; [
    pkgs.rsync
  ];

  programs.neovim = {
    enable = true;
    package = (lib.infuse pkgs.neovim {
      __output.checkPhase.__assign = "true";
    });
    defaultEditor = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    withPython3 = false;
    withNodeJs = false;
    withRuby = false;

    extraPackages = with pkgs; [
      tree-sitter
      luajitPackages.lua
    ];
  };

  rix101.shell = {
    enable = true;
    username = "reo101";
    hostname = "cheetah";
    atuin = true;
    direnv = true;
    zoxide = true;
    shells = [
      "zsh"
      "nushell"
    ];
  };

  rix101.scm = {
    git.enable = true;
    jj.enable = true;
  };

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 86400;
    maxCacheTtl = 86400;
    pinentry.package = pkgs.pinentry-tty;
    enableSshSupport = true;
    sshKeys = [ "CFDE97EDC2FDB2FD27020A084F1E3F40221BAFE7" ];
  };

  home.sessionVariables."PASSWORD_STORE_DIR" = "${config.xdg.dataHome}/password-store";
}
