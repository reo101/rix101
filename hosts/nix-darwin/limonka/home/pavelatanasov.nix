{ inputs, lib, pkgs, config, ... }:

{
  imports = [
    ../modules/taskwarrior.nix
  ];

  home = {
    username = lib.mkForce "pavelatanasov";
    homeDirectory = lib.mkForce "/Users/pavelatanasov";
    stateVersion = "23.05";
  };

  # Set env vars
  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.command-not-found.enable = true;

  home.packages = with pkgs; [
    # WM
    yabai
    skhd

    # Discord
    discord

    # Shell
    btop
    ripgrep
    zellij

    # Neovim
    neovim
    # (neovim.overrideAttrs (oldAttrs: {
    #   lua = luajitcoroutineclone;
    # }))
    (pkgs.writeShellScriptBin "lua" "exec -a $0 ${luajitPackages.nlua}/bin/nlua $@")
    # luajitPackages.nlua
    fennel
    # fennel-language-server
    fennel-ls
    git
    gh

    # (gnumake.override { guileSupport = true; })
    gnumake

    # # Emacs
    # (emacs-unstable.override {
    #    withGTK3 = true;
    #    :
    #  })

    # Dhall
    # dhall
    # dhall-lsp-server

    # Circom
    # circom
    # circom-lsp

    # Nix
    nil
    # nixd
    nurl

    # Mail
    himalaya

    # Java
    graalvm-ce

    # SSH and GPG
    openssh
    gnupg
    pinentry_mac
    (pass.withExtensions (extensions: with extensions; [
      pass-otp
    ]))

    # GCP
    google-cloud-sdk

    # FMI
    vim-fmi-cli

    # Zig
    zigpkgs.master
    # inputs.zls-overlay.packages.${pkgs.system}.default

    # Android
    android-tools
  ];

  reo101 = {
    shell = {
      enable = true;
      shells = [ "zsh" "nushell" ];
      starship = true;
      atuin = true;
      carapace = true;
      direnv = true;
      gpg.enable = true;
      zoxide = true;
    };
    scm = {
      git.enable = true;
      jj.enable = true;
    };
    wezterm = {
      enable = true;
    };
    spotify = {
      enable = false;
    };
  };
}
