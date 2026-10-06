{ inputs, lib, pkgs, config, ... }:

let
  username = "reo101";
  rustdeskX11 = pkgs.symlinkJoin {
    name = "rustdesk-x11";
    paths = [ pkgs.rustdesk ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # HACK: keyboard capture is unreliable in the default Wayland mode
    postBuild = ''
      wrapProgram $out/bin/rustdesk \
        --set GDK_BACKEND x11 \
        --set GTK_USE_PORTAL 0
    '';
  };
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
    inputs.self.modules.home-manager.ida-pro
    inputs.self.modules.home-manager.yubikey-touch-detector
  ];

  home = {
    inherit username;
    homeDirectory = lib.mkForce "/home/${username}";
    stateVersion = "25.05";
  };

  rix101.firefox.enable = true;

  # NOTE: enable stuff like `Music` dir
  xdg.userDirs = {
    enable = true;
    setSessionVariables = true;
  };

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
    pkgs.discord-ptb
    pkgs.legcord
    pkgs.mumble
    pkgs.element-desktop
    pkgs.himalaya
    (pkgs.pass.withExtensions (
      extensions: [
        extensions.pass-otp
      ]
    ))

    # Remote debugging
    rustdeskX11

    # Learning
    (pkgs.anki.withAddons [
      pkgs.ankiAddons.adjust-sound-volume
      pkgs.ankiAddons.anki-connect
      pkgs.ankiAddons.review-heatmap
      pkgs.custom.anki-study-time-stats
      pkgs.ankiAddons.reviewer-refocus-card
      pkgs.ankiAddons.yomichan-forvo-server
    ])

    # VW
    pkgs.bitwarden-cli
    pkgs.bitwarden-desktop
    # pkgs.keyguard

    # Work
    (pkgs.azure-cli.withExtensions [
      pkgs.azure-cli.extensions.azure-devops
    ])
  ];

  rix101 = {
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
    mpd-satellite.enable = true;
  };

  home.services.osu-touchpad = {
    imports = [ pkgs.custom.osu-touchpad.services.default ];

    osu-touchpad = {
      watchProcess = "osu!";
      focusMatch = "osu";
      focusQuery = "${lib.getExe config.programs.niri.package} msg focused-window";
      # Map the top-right region of the pad to the output.
      activeArea = rec {
        xMin = xMax - 2805;
        xMax = 3841;
        yMin = 0;
        yMax = (xMax - xMin) * 3 / 4;
      };
      clickOnTouch = false;
      debug = true;
    };

    systemd.service = {
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = lib.mkForce [ "graphical-session.target" ];
    };
  };

  home.services.clipboard-url-cleaner.imports = [ pkgs.custom.clipboard-url-cleaner.services.default ];

  services.yubikey-touch-detector = {
    enable = true;
  };

  programs.emacs = {
    enable = true;
    # NOTE: Using X11 Emacs (not PGTK) for smooth ultra-scroll on high-refresh displays
    # PGTK has event batching issues with niri that cause 300ms+ scroll freezes
    package = pkgs.emacs31;
    extraPackages = epkgs: [
      epkgs.treesit-grammars.with-all-grammars
    ];
  };
  services.emacs.enable = true;
}
