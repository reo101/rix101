{ inputs, lib, pkgs, config, ... }:

{
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
      shells = [ "nushell" "zsh" ];
      starship = true;
      atuin = true;
      direnv = true;
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

  # programs.git = {
  #   enable = true;
  #   userName = "reo101";
  #   # userEmail = "pavel.atanasov@limechain.tech";
  #   userEmail = "pavel.atanasov2001@gmail.com";
  #   signing = {
  #     signByDefault = true;
  #     key = "675AA7EF13964ACB";
  #   };
  #   # init.defaultBranch = "master";
  #   lfs = {
  #     enable = true;
  #   };
  # };


  home.file.".gnupg/gpg-agent.conf" = {
    text = ''
      allow-preset-passphrase
      max-cache-ttl 86400
      default-cache-ttl 86400
      enable-ssh-support
      pinentry-program ${pkgs.pinentry_mac}/Applications/pinentry-mac.app/Contents/MacOS/pinentry-mac
      # pinentry-program /usr/local/opt/pinentry-touchid/bin/pinentry-touchid
    '';
  };

  home.file.".gnupg/sshcontrol" = {
    text = ''
      CFDE97EDC2FDB2FD27020A084F1E3F40221BAFE7
    '';
  };

  programs.zsh.initExtra = ''
    # if [ "''${SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
    #   export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
    # fi
    # if [ -z "$SSH_AUTH_SOCK" ]; then
    #   export SSH_AUTH_SOCK=$(${pkgs.gnupg}/bin/gpgconf --list-dirs agent-ssh-socket)
    # fi
    unset SSH_AGENT_PID
    export SSH_AUTH_SOCK=$(${pkgs.gnupg}/bin/gpgconf --list-dirs agent-ssh-socket)
    gpg-connect-agent updatestartuptty /bye >/dev/null
    export GPG_TTY=$(tty)
  '';
}
