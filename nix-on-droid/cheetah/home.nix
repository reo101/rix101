{ lib, config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    username = "nix-on-droid";
    # username = "reo101";
    homeDirectory = "/data/data/com.termux.nix/files/home";
    stateVersion = "22.05";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # neovim
    # clang
    gcc

    diffutils
    findutils
    utillinux
    tzdata
    hostname
    man
    ncurses
    gnugrep
    gnupg
    gnused
    gnutar
    bzip2
    gzip
    xz
    zip
    unzip

    # Bling
    onefetch
    neofetch

    # Utils
    ripgrep

    # Passwords
    pass
    passExtensions.pass-otp

    # Dhall
    dhall
    dhall-lsp-server
  ];

  # nixpkgs = {
  #   overlays = [
  #     inputs.neovim-nightly-overlay.overlay
  #     inputs.zig-overlay.overlay
  #   ];
  #
  #   config.allowUnfree = true;
  # };

  nixpkgs = {
    overlays = [
      (import (builtins.fetchTarball {
        url = https://github.com/nix-community/neovim-nightly-overlay/archive/master.tar.gz;
      }))
    ];

    config.allowUnfree = true;
  };

  # programs.zig = {
  #   enable = true;
  #   package = pkgs.zig;
  # };

  programs.neovim = {
    enable = true;
    package = pkgs.neovim-nightly;
    # defaultEditor = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    withPython3 = false;
    withNodeJs = false;
    withRuby = false;

    # neovimRcContent = "";

    extraPackages = with pkgs; [
        tree-sitter
        rnix-lsp
        # sumneko-lua-language-server
        # stylua
        # texlab
        # rust-analyzer
    ];
  };

  home.file = {
    ".config/nvim" = {
      recursive = true;
      source = /data/data/com.termux.nix/files/home/.local/src/reovim;
    };
  };

  programs.git = {
    enable = true;
    userName = "reo101";
    # userName = "Pavel Atanasov";
    userEmail = "pavel.atanasov2001@gmail.com";
  };

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 1800;
    enableSshSupport = true;
  };
}
