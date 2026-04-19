{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:

{
  imports = [
    ./homeModules/taskwarrior.nix
  ];

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    username = "nix-on-droid";
    # username = "reo101";
    homeDirectory = "/data/data/com.termux.nix/files/home";
    stateVersion = "23.05";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # neovim
    # clang
    gcc

    openssh
    (writeShellScriptBin "sshd-start" ''
      set -eu

      home_dir="''${HOME:-/data/data/com.termux.nix/files/home}"
      repo="''${RIX101_CONFIG:-$home_dir/.config/rix101}"
      state_dir="$home_dir/.local/state/sshd"
      config_file="$home_dir/.config/sshd/sshd_config"
      host_key="$state_dir/ssh_host_ed25519_key"

      mkdir -p "$state_dir"

      if [ ! -f "$host_key" ]; then
        nix shell --inputs-from "$repo" nixpkgs-for-nod#openssh -c \
          ssh-keygen -t ed25519 -N "" -f "$host_key"
      fi

      exec nix shell --inputs-from "$repo" nixpkgs-for-nod#openssh -c \
        sh -c 'exec "$(command -v sshd)" "$@"' sshd \
        -E "$state_dir/sshd.log" \
        -f "$config_file" \
        "$@"
    '')
    diffutils
    findutils
    util-linux
    curl
    wget
    tzdata
    hostname
    man
    ncurses
    gnugrep
    gnupg
    gnused
    gnutar
    (gnumake.override { guileSupport = true; })
    bzip2
    gzip
    xz
    zip
    unzip

    zellij

    direnv
    nix-direnv
    # inputs.nil.packages.${pkgs.system}.nil
    nil

    # Bling
    onefetch
    fastfetch

    # Utils
    ripgrep
    duf
    watchman

    # Email
    himalaya

    # XMPP
    profanity

    # Passwords
    (pass.withExtensions (
      extensions: with extensions; [
        pass-otp
      ]
    ))
  ];

  programs.neovim = {
    enable = true;
    package = pkgs.neovim;
    defaultEditor = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    withPython3 = false;
    withNodeJs = false;
    withRuby = false;

    # neovimRcContent = "";

    extraPackages = with pkgs; [
      tree-sitter
      luajitPackages.lua
      # rnix-lsp
      # sumneko-lua-language-server
      # stylua
      # texlab
      # rust-analyzer
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

  home.file = {
    ".config/nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.local/src/reovim";
    };
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
