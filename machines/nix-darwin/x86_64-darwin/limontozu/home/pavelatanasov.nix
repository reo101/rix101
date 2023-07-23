{ inputs, outputs, lib, pkgs, config, ... }:

{
  home = {
    username = lib.mkForce "pavelatanasov";
    homeDirectory = lib.mkForce "/Users/pavelatanasov";
    stateVersion = "23.05";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Use this flake's version of nixpkgs
  home.sessionVariables = {
    # NIX_PATH = "nixpkgs=${inputs.nixpkgs}";
    NIX_PATH =
      builtins.concatStringsSep
        ":"
        (lib.mapAttrsToList
          (name: input:
            "${name}=${input.sourceInfo.outPath}")
          inputs);
  };

  # {
  #   _type = "flake";
  #   inputs = <CODE>;
  #   lastModified = 1686838567;
  #   lastModifiedDate = "20230615141607";
  #   narHash = "sha256-aqKCUD126dRlVSKV6vWuDCitfjFrZlkwNuvj5LtjRRU=";
  #   nixosModules = <CODE>;
  #   outPath = "/nix/store/mf3nazm479fkbh9n3v7n73yrcvr8avi6-source";
  #   outputs = {
  #     nixosModules = <CODE>;
  #   };
  #   rev = "429f232fe1dc398c5afea19a51aad6931ee0fb89";
  #   shortRev = "429f232";
  #   sourceInfo = {
  #     lastModified = 1686838567;
  #     lastModifiedDate = "20230615141607";
  #     narHash = "sha256-aqKCUD126dRlVSKV6vWuDCitfjFrZlkwNuvj5LtjRRU=";
  #     outPath = "/nix/store/mf3nazm479fkbh9n3v7n73yrcvr8avi6-source";
  #     rev = "429f232fe1dc398c5afea19a51aad6931ee0fb89";
  #     shortRev = "429f232";
  #   };
  # }

  home.packages = with pkgs; [
    # WM
    yabai
    skhd

    # Shell
    btop
    ripgrep

    # Neovim
    neovim
    fennel
    fennel-language-server

    # Dhall
    dhall
    dhall-lsp-server

    # Circom
    circom
    circom-lsp

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

    # Android
    android-tools
  ];

  reo101 = {
    shell = {
      enable = true;
      atuin = true;
      direnv = true;
      zoxide = true;
      extraConfig = ''
        function take() {
          mkdir -p "''$''\{@''\}" && cd "''$''\{@''\}"
        }
      '';
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
