{ inputs, outputs, lib, pkgs, config, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    username = "nix-on-droid";
    # username = "reo101";
    homeDirectory = "/data/data/com.termux.nix/files/home";
    stateVersion = "23.05";
  };

  # Add custom overlays
  nixpkgs = {
    overlays = [
      inputs.neovim-nightly-overlay.overlay
      inputs.zig-overlay.overlays.default
      # inputs.zls-overlay.???
    ];
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

    direnv
    nix-direnv

    # Bling
    onefetch
    neofetch

    # Utils
    ripgrep
    duf

    # Passwords
    (pass.withExtensions (extensions: with extensions; [
      pass-otp
    ]))

    # Dhall
    # dhall
    # dhall-lsp-server

    # Zig
    # zigpkgs.master
    # inputs.zls-overlay.packages.aarch64-linux.default

    # Emacs
    # emacs

    #
    j
  ];

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

  reo101.shell = {
    enable = true;
    username = "reo101";
    hostname = "cheetah";
    direnv = true;
    zoxide = true;
  };

  home.file = {
    ".config/nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.local/src/reovim";
    };
  };

  programs.git = {
    enable = true;
    userName = "reo101";
    userEmail = "pavel.atanasov2001@gmail.com";
  };

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 1800;
    enableSshSupport = true;
  };

  # Using nix-direnv
  # services.lorri = {
  #   enable = true;
  # };
}
