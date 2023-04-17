{ inputs, outputs, lib, pkgs, config, ... }:

{
  home = {
    username = lib.mkForce "pavelatanasov";
    homeDirectory = lib.mkForce "/Users/pavelatanasov";
    stateVersion = "22.11";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Use this flake's version of nixpkgs
  home.sessionVariables = {
    NIX_PATH = "nixpkgs=${inputs.nixpkgs}";
  };

  home.packages = with pkgs; [
    # WM
    yabai
    skhd

    # Neovim
    neovim

    # Dhall
    dhall
    dhall-lsp-server

    # Nix
    rnix-lsp
    nil

    # FMI
    vim-fmi-cli

    # Zig
    zigpkgs.master
    inputs.zls-overlay.packages.x86_64-darwin.default
  ];

  reo101 = {
    shell = {
      enable = true;
      direnv = true;
      zoxide = true;
    };
    wezterm = {
      enable = true;
    };
  };

  nixpkgs = {
    overlays = lib.attrValues outputs.overlays ++ [
      inputs.neovim-nightly-overlay.overlay
      inputs.zig-overlay.overlays.default
    ];

    config.allowUnfree = true;
  };

  programs.git = {
    enable = true;
    userName = "pavelatanasov";
    userEmail = "pavel.atanasov@limechain.tech";
    # signing = {
    #   signByDefault = true;
    #   key = "0x52F3E1D376F692C0";
    # };
  };

  # services.gpg-agent = {
  #   enable = true;
  #   defaultCacheTtl = 1800;
  #   enableSshSupport = true;
  # };
}
