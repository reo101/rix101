{ inputs, outputs, lib, config, pkgs, ... }:

{
  imports = builtins.attrValues outputs.homeManagerModules;

  home = {
    username = "reo101";
    homeDirectory = "/home/reo101";
    stateVersion = "22.11";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # WM
    river

    # Terminals
    wezterm
    foot

    # Core
    neovim
    git
    firefox
    discord
    vifm

    # Shell
    zsh
    starship
    zoxide

    # Dhall
    dhall
    dhall-lsp-server

    # Nix
    rnix-lsp
    nil
    direnv

    # Torrents
    tremc

    # Zig
    # zigpkgs."0.10.1"
    zigpkgs.master
    # inputs.zls-overlay.packages.x86_64-linux.default
  ];

  nixpkgs = {
    overlays = [
      # inputs.neovim-nightly-overlay.overlay
      inputs.zig-overlay.overlays.default
    ];

    config.allowUnfree = true;
  };

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
    # signing = {
    #   signByDefault = true;
    #   key = "0x52F3E1D376F692C0";
    # };
  };

  reo101.shell = {
    enable = true;
  };

  home.file = {
    ".config/nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.local/src/reovim";
    };
  };

  home.file.".config/river/init" = {
    executable = true;
    source = ./../river;
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
