{ inputs, lib, pkgs, config, ... }:

{
  imports = [
    inputs.wired.homeManagerModules.default
  ];

  home = {
    username = "reo101";
    homeDirectory = "/home/reo101";
    stateVersion = "22.11";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    ## WM
    # river
    # swww # wallpaper deamon
    # # wired-notify # dunst on wayland
    # waybar # status bar
    # xwayland
    # wl-clipboard
    # slurp # select regions from wayland
    # grim # grap images from regions
    # playerctl # music control

    ## Terminals
    # wezterm
    foot

    ## Core
    neovim
    fennel-language-server
    git
    gnupg
    firefox
    discord
    armcord # modded discord
    vifm # file editor
    pciutils # lspci
    usbutils # lsusb
    (uutils-coreutils.override { prefix = ""; }) # coreutils in rust

    ## Shell
    # zsh
    # starship
    # zoxide
    ripgrep

    ## Dhall
    dhall
    # dhall-lsp-server

    ## Nix
    nil
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

    ## Vim FMI
    vim-fmi-cli

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

  reo101 = {
    shell = {
      enable = true;
      direnv = true;
      zoxide = true;
    };
    river = {
      enable = true;
    };
    wezterm = {
      enable = true;
    };
  };

  home.file = {
    ".config/nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.local/src/reovim";
    };
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
