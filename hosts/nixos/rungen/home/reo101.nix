{
  inputs,
  pkgs,
  lib,
  ...
}:

let
  username = "reo101";
in
{
  imports = [
    ../homeModules/mpd.nix
    ../homeModules/mpv.nix
    ../homeModules/atuin.nix
    ../homeModules/taskwarrior.nix
    ../homeModules/games.nix
    ../homeModules/ghostty
    ../homeModules/easyeffects.nix
  ];

  home = {
    inherit username;
    homeDirectory = lib.mkForce "/home/${username}";
    stateVersion = "25.05";
  };

  # NOTE: enable stuff like `Music` dir
  xdg.userDirs.enable = true;

  home.packages = [
    ## Core
    pkgs.ripgrep
    pkgs.fd
    pkgs.gnupg
    pkgs.pciutils # lspci
    pkgs.usbutils # lsusb

    ## WM
    pkgs.pamixer
    pkgs.playerctl
    pkgs.brightnessctl
    pkgs.pavucontrol

    # Fluff
    pkgs.btop
    pkgs.fastfetch

    # Music
    pkgs.mpc
    pkgs.rmpc
    pkgs.spotify

    # Communication
    pkgs.discord
    pkgs.legcord
    pkgs.mumble

    # Learning
    (pkgs.anki.withAddons (
      with pkgs.ankiAddons;
      [
        adjust-sound-volume
        anki-connect
        review-heatmap
        reviewer-refocus-card
        yomichan-forvo-server
      ]
    ))
  ];

  # Discord's Rich Presence (RPC)
  services.arrpc = {
    enable = true;
    package = pkgs.arrpc;
  };

  reo101 = {
    shell = {
      enable = true;
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
      jj.enable = true;
    };
  };

  services.yubikey-touch-detector = {
    enable = true;
  };

  programs.emacs = {
    enable = true;
    # NOTE: Using X11 Emacs (not PGTK) for smooth ultra-scroll on high-refresh displays
    # PGTK has event batching issues with niri that cause 300ms+ scroll freezes
    package = pkgs.emacs30;
    extraPackages = epkgs: [
      epkgs.treesit-grammars.with-all-grammars
    ];
  };
  services.emacs.enable = true;
}
