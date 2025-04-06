{ inputs, lib, pkgs, config, ... }:

{
  imports = [
    inputs.wired.homeManagerModules.default
    ../../../nix-darwin/limonka/homeModules/taskwarrior.nix
    ../homeModules/niri.nix
    ../homeModules/mpv.nix
  ];

  home = {
    username = "reo101";
    homeDirectory = "/home/reo101";
    stateVersion = "24.11";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    ## Core
    # neovim
    gnupg
    pciutils # lspci
    usbutils # lsusb

    ## Terminal
    foot
    ghostty
    wezterm

    ## WM
    river
    pamixer
    playerctl
    brightnessctl
    pavucontrol

    ## Shell
    # zsh
    # starship
    # zoxide
    ripgrep

    ## Nix
    direnv

    ## Torrents
    tremc

    ## Anki
    anki

    # Gaming
    prismlauncher
    discord-rpc

    # Fluff
    btop
    fastfetch
  ];

  reo101 = {
    shell = {
      enable = true;
      shells = [ "zsh" "nushell" ];
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
      jj.enable = true;
    };
  };

  services.mako = {
    enable = true;
    settings = {
      layer = "overlay";
      default-timeout = 5000;
      height = 1000;
    };
  };
}
