{ inputs, outputs, lib, pkgs, config, ... }:

{
  imports = [
    inputs.wired.homeManagerModules.default
  ];

  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays ++ [
      inputs.neovim-nightly-overlay.overlay
      inputs.zig-overlay.overlays.default
      inputs.wired.overlays.default
    ];

    config.allowUnfree = true;
  };

  home = {
    username = "reo101";
    homeDirectory = "/home/reo101";
    stateVersion = "22.11";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    ## WM
    river
    swww # wallpaper deamon
    # wired-notify # dunst on wayland
    waybar # status bar
    xwayland
    wl-clipboard
    slurp # select regions from wayland
    grim # grap images from regions

    ## Terminals
    # wezterm
    foot

    ## Core
    neovim
    git
    firefox
    discord
    vifm # file editor
    pciutils # lspci
    usbutils # lsusb

    ## Shell
    # zsh
    # starship
    # zoxide
    ripgrep

    ## Dhall
    dhall
    dhall-lsp-server

    ## Nix
    rnix-lsp
    nil
    direnv

    ## Torrents
    tremc

    ## Rust
    rustc
    cargo

    ## Zig
    # zigpkgs."0.10.1"
    zigpkgs.master
    # inputs.zls-overlay.packages.x86_64-linux.default
  ];

  # Enable the GPG Agent daemon.
  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 1800;
    enableSshSupport = true;
  };

  programs.git = {
    enable = true;
    userName = "reo101";
    userEmail = "pavel.atanasov2001@gmail.com";
  };

  reo101 =  {
    shell = {
      enable = true;
      direnv = true;
      zoxide = true;
    };
    wezterm = {
      enable = true;
    };
  };

  systemd.user.services."swww" = {
    Unit = {
      Description = "Swww Daemon";
      PartOf = "graphical-session.target";
    };
    Service = {
      ExecStart = "${pkgs.swww}/bin/swww init";
      ExecStop = "${pkgs.swww}/bin/swww kill";
      Type = "simple";
      Restart = "always";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # services.swww = {
  #   enabled = true;
  # };

  services.wired = {
    enable = true;
    config = ../configs/wired.ron;
  };

  home.file = {
    ".config/nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.local/src/reovim";
    };
  };

  home.file.".config/river/init" = {
    executable = true;
    source = ../configs/river;
  };

  # home.file.".stack/config.yaml".text = lib.generators.toYAML {} {
  #   templates = {
  #     scm-init = "git";
  #     params = with config.programs.git; {
  #       author-name = userName;
  #       author-email = userEmail;
  #       github-username = userName;
  #     };
  #   };
  #   nix.enable = true;
  # };

}
