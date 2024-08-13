{ inputs, lib, pkgs, config, ... }:

{
  imports = [
    inputs.wired.homeManagerModules.default
  ];

  home = {
    username = "jeeves";
    homeDirectory = "/home/jeeves";
    stateVersion = "23.05";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    ## Core
    # neovim
    git
    gnupg
    pciutils # lspci
    usbutils # lsusb

    ## Shell
    # zsh
    # starship
    # zoxide
    ripgrep

    ## Nix
    direnv

    ## Torrents
    tremc

    ## Rust
    rustc
    cargo
    rust-analyzer
    clang
    openssl
    pkg-config
  ];

  reo101 = {
    shell = {
      enable = true;
      direnv = true;
      zoxide = true;
      shells = [
        "zsh"
        "nushell"
      ];
    };
  };

  home.file = {
    ".config/nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.local/src/reovim";
    };
  };
}
