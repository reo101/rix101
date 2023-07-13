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

    # Shell
    btop
    ripgrep

    # Neovim
    neovim
    fennel-language-server

    # Dhall
    dhall
    dhall-lsp-server

    # Nix
    rnix-lsp
    nil

    # SSH and GPG
    openssh
    gnupg
    pinentry_mac
    (pass.withExtensions (extensions: with extensions; [
        pass-otp
    ]))

    # FMI
    vim-fmi-cli

    # Zig
    zigpkgs.master
    inputs.zls-overlay.packages.x86_64-darwin.default

    # Polkadot
    srtool-cli
    pest-ide-tools
  ];

  reo101 = {
    shell = {
      enable = true;
      atuin = true;
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
    userName = "reo101";
    # userEmail = "pavel.atanasov@limechain.tech";
    userEmail = "pavel.atanasov2001@gmail.com";
    signing = {
      signByDefault = true;
      key = "675AA7EF13964ACB";
    };
  };

  home.file.".gnupg/gpg-agent.conf" = {
    text = ''
      allow-preset-passphrase
      max-cache-ttl 86400
      default-cache-ttl 86400
      enable-ssh-support
      # pinentry-program ${pkgs.pinentry_mac}/Applications/pinentry-mac.app/Contents/MacOS/pinentry-mac
      # pinentry-program /usr/local/opt/pinentry-touchid/bin/pinentry-touchid
    '';
  };

  home.file.".gnupg/sshcontrol" = {
    text =''
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
