{
  lib,
  pkgs,
  ...
}:
let
  username = "reo101";
in
{
  home = {
    inherit username;
    homeDirectory = lib.mkForce "/home/${username}";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;

  xdg.userDirs.enable = true;

  home.packages = [
    pkgs.neovim
    pkgs.ripgrep
    pkgs.fd
    pkgs.gnupg
    pkgs.pciutils
    pkgs.usbutils
    pkgs.btop
    pkgs.fastfetch
  ];

  reo101 = {
    shell = {
      enable = true;
      hostname = "iso";
      shells = [
        "zsh"
        "nushell"
      ];
      starship = true;
      atuin = true;
      carapace = true;
      direnv = true;
      gpg.enable = true;
      zellij = true;
      zoxide = true;
    };
    scm = {
      git.enable = true;
      jj = {
        enable = true;
        nvim = false;
      };
    };
  };
}
