{
  meta,
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.rix101.shell;

  inherit (lib)
    mkEnableOption
    mkOption
    types
    mkIf
    optionals
    optionalString
    mkMerge
    ;

  carapaceBridges = "inshellisense,carapace,zsh,fish,bash";

  # Cache dynamic shell init snippets at build time. Spawning helper binaries
  # just to print mostly-static zsh is very visible on cold or slow filesystems.
  # Keep the generated files in the Nix store (not XDG_CACHE_HOME) so deleting
  # user caches never breaks shell startup. Syntax-check every snippet while
  # building so upstream init-output changes fail early.
  zshCachedInit =
    name: nativeBuildInputs: script:
    pkgs.runCommand "rix101-shell-zsh-${name}-init"
      {
        nativeBuildInputs = [ pkgs.zsh ] ++ nativeBuildInputs;
      }
      ''
        mkdir -p "$out"
        ${script}
        zsh -n "$out/init.zsh"
        zsh -fc 'zcompile -UR "$1"' -- "$out/init.zsh"
      '';

  zshAtuinInit = zshCachedInit "atuin" [ ] ''
    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$TMPDIR/config"
    export XDG_DATA_HOME="$TMPDIR/data"
    mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"

    ${lib.getExe pkgs.atuin} init zsh > "$out/init.zsh"
    substituteInPlace "$out/init.zsh" \
      --replace-fail 'atuin ' '${lib.getExe pkgs.atuin} '
    substituteInPlace "$out/init.zsh" \
      --replace-fail 'export ATUIN_SESSION=$(${lib.getExe pkgs.atuin} uuid)' 'if [ -r /proc/sys/kernel/random/uuid ]; then
        IFS= read -r ATUIN_SESSION < /proc/sys/kernel/random/uuid
        export ATUIN_SESSION
    else
        export ATUIN_SESSION=$(${lib.getExe pkgs.atuin} uuid)
    fi'
  '';

  zshCarapaceInit =
    zshCachedInit "carapace"
      (
        [
          pkgs.bashInteractive
          pkgs.fish
        ]
        ++ lib.optional (
          pkgs ? inshellisense && lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.inshellisense
        ) pkgs.inshellisense
      )
      ''
        export HOME="$TMPDIR/home"
        export XDG_CONFIG_HOME="$TMPDIR/config"
        export CARAPACE_BRIDGES=${lib.escapeShellArg carapaceBridges}
        mkdir -p "$HOME" "$XDG_CONFIG_HOME"

        ${lib.getExe pkgs.carapace} _carapace zsh > "$out/init.zsh"
        substituteInPlace "$out/init.zsh" \
          --replace-fail "$XDG_CONFIG_HOME/carapace" '${config.xdg.configHome}/carapace'
        substituteInPlace "$out/init.zsh" \
          --replace-fail 'xargs carapace ' 'xargs ${lib.getExe pkgs.carapace} '
      '';

  zshDirenvInit = zshCachedInit "direnv" [ ] ''
    ${lib.getExe pkgs.direnv} hook zsh > "$out/init.zsh"
  '';

  zshStarshipInit = zshCachedInit "starship" [ ] ''
    ${lib.getExe pkgs.starship} init zsh > "$out/init.zsh"
  '';

  zshZoxideInit = zshCachedInit "zoxide" [ ] ''
    ${lib.getExe pkgs.zoxide} init zsh > "$out/init.zsh"
    substituteInPlace "$out/init.zsh" \
      --replace-fail '\command zoxide' '\command ${lib.getExe pkgs.zoxide}'
  '';

  shellAliases = {
    # cp = "${pkgs.custom.advcpmv}/bin/advcp -rvi";
    # mv = "${pkgs.custom.advcpmv}/bin/advmv -vi";
    rebuild =
      let
        rebuild_script = pkgs.writeShellScript "rebuild" ''
          ${
            let
              inherit (lib.strings)
                hasInfix
                ;
              inherit (pkgs.stdenv.hostPlatform)
                isx86_64
                isAarch64
                isLinux
                isDarwin
                ;
            in
            if isx86_64 && isLinux then
              "sudo --validate && sudo nixos-rebuild"
            else if isDarwin then
              "darwin-rebuild"
            else if isAarch64 then
              "nix-on-droid"
            else
              "home-manager"
          } --flake ${
            if cfg.hostname != null then "${cfg.flakePath}#${cfg.hostname}" else "${cfg.flakePath}"
          } ''$''\{1:-switch''\} "''$''\{@:2''\}" # |& nix run nixpkgs#nix-output-monitor
        '';
      in
      "${rebuild_script}";
  };
in
{
  imports = [
  ];

  options = {
    rix101.shell = {
      enable = mkEnableOption "rix101 shell setup";
      username = mkOption {
        description = "Username to be used (for prompt)";
        type = types.str;
        default = "${config.home.username}";
      };
      hostname = mkOption {
        description = "Hostname to be used (for `rebuild`)";
        type = types.nullOr types.str;
        default = null;
      };
      shells = mkOption {
        description = "Shells to be configured (first one is used for $SHELL)";
        type =
          lib.pipe
            [
              "nushell"
              "zsh"
            ]
            [
              types.enum
              types.listOf
            ];
        default = [
          "nushell"
          "zsh"
        ];
      };
      starship = mkOption {
        description = "Use starship prompt";
        type = types.bool;
        default = true;
      };
      atuin = mkOption {
        description = "Integrate with atuin";
        type = types.bool;
        default = true;
      };
      carapace = mkOption {
        description = "Integrate with carapace";
        type = types.bool;
        default = true;
      };
      direnv = mkOption {
        description = "Integrate with direnv";
        type = types.bool;
        default = true;
      };
      gpg = {
        enable = mkEnableOption "GPG setup";
        pinentryPackage = mkOption {
          type = types.nullOr types.package;
          example = lib.literalExpression "pkgs.pinentry-gnome3";
          default = null;
        };
      };
      zellij = mkOption {
        description = "Integrate with zellij";
        type = types.bool;
        default = true;
      };
      zoxide = mkOption {
        description = "Integrate with zoxide";
        type = types.bool;
        default = true;
      };
      flakePath = mkOption {
        description = "Flake path (for `rebuild`)";
        type = types.str;
        default = "${config.xdg.configHome}/rix101";
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      lib.concatLists [
        (optionals cfg.starship [
          starship
        ])
        (optionals cfg.atuin [
          atuin
        ])
        (optionals cfg.carapace [
          carapace
        ])
        (optionals cfg.direnv [
          direnv
        ])
        (optionals cfg.gpg.enable [
          gnupg
          yubikey-manager
          yubikey-personalization
        ])
        (optionals cfg.zellij [
          zellij
        ])
        (optionals cfg.zoxide [
          zoxide
        ])
      ];

    xdg.configFile."atuin/config.toml" = mkIf cfg.atuin {
      # TODO: use pkgs.substituteAll
      # TODO: agenix?
      text = import ./atuin.nix {
        keyPath = "${config.xdg.dataHome}/atuin/key";
      };
    };

    # Carapace
    programs.carapace = mkIf cfg.carapace {
      enable = true;
      enableZshIntegration = false;
    };

    # Direnv
    programs.direnv = mkIf cfg.direnv {
      enable = true;

      enableNushellIntegration = builtins.elem "nushell" cfg.shells;
      enableZshIntegration = false;

      nix-direnv = {
        enable = true;
      };
    };

    # Starship
    programs.starship = mkIf cfg.starship {
      enable = true;

      package = pkgs.starship;

      settings = import ./starship.nix {
        inherit (cfg) username;
      };

      enableNushellIntegration = builtins.elem "nushell" cfg.shells;
      enableZshIntegration = false;
    };

    # Zellij
    programs.zellij = mkIf cfg.zellij {
      enable = true;

      package = pkgs.zellij;

      # NOTE: runs inside every shell, not wanted
      # enableZshIntegration = builtins.elem "zsh" cfg.shells;
      enableZshIntegration = false;
    };

    # Zoxide
    programs.zoxide = mkIf cfg.zoxide {
      enable = true;

      package = pkgs.zoxide;

      enableNushellIntegration = builtins.elem "nushell" cfg.shells;
      enableZshIntegration = false;
    };

    # GnuPG
    services.gpg-agent =
      mkIf cfg.gpg.enable (
        let
          # 24 hours
          ttl = 24 * 60 * 60;
        in
        {
          enable = true;
          defaultCacheTtl = 86400;
          maxCacheTtl = 86400;
          pinentry.package =
            if cfg.gpg.pinentryPackage != null then
              cfg.gpg.pinentryPackage
            else if pkgs.stdenv.hostPlatform.isDarwin then
              pkgs.pinentry_mac
            # TODO: `pinentry` for GUI systems
            else if meta.gui then
              pkgs.pinentry-qt
            else
              pkgs.pinentry-tty;
          enableSshSupport = true;
          enableZshIntegration = false;
          sshKeys = [
            # NOTE: will mainly be using `YubiKey`s, this is a fallback
            "CFDE97EDC2FDB2FD27020A084F1E3F40221BAFE7"
          ];
        }
      )
      // {
        enableNushellIntegration = builtins.elem "nushell" cfg.shells;
        enableZshIntegration = false;
      };

    # Shell
    home.sessionVariables = mkMerge [
      {
        SHELL =
          let
            shellPackage = config.programs.${builtins.head cfg.shells}.package;
          in
          "${shellPackage}/${shellPackage.shellPath}";
        EDITOR = "nvim";
        MANPAGER = "nvim +Man!";
      }
      (mkIf cfg.carapace {
        CARAPACE_BRIDGES = carapaceBridges;
      })
      (mkIf cfg.direnv {
        DIRENV_WARN_TIMEOUT = "0";
      })
    ];

    # Nushell
    programs.nushell = mkMerge [
      (mkIf (builtins.elem "nushell" cfg.shells) {
        enable = true;

        package = pkgs.nushell;

        configFile.source = ./nushell/config.nu;
        envFile.source = ./nushell/env.nu;
        loginFile.source = ./nushell/login.nu;

        inherit shellAliases;

        environmentVariables = { };
      })
      (mkIf cfg.atuin {
        extraEnv = # nu'
          ''
            let atuin_cache = "${config.xdg.cacheHome}/atuin"
            if not ($atuin_cache | path exists) {
                mkdir $atuin_cache
            }
            ${pkgs.atuin}/bin/atuin init nu | save --force ${config.xdg.cacheHome}/atuin/init.nu
          '';

        extraConfig = # nu'
          ''
            source ${config.xdg.cacheHome}/atuin/init.nu

            # Ctrl-R
            $env.config = (
                $env.config | upsert keybindings (
                    $env.config.keybindings
                    | append {
                        name: atuin
                        modifier: control
                        keycode: char_r
                        mode: [emacs, vi_normal, vi_insert]
                        event: { send: executehostcommand cmd: (_atuin_search_cmd) }
                    }
                )
            )

            # Up
            $env.config = (
                $env.config | upsert keybindings (
                    $env.config.keybindings
                    | append {
                        name: atuin
                        modifier: none
                        keycode: up
                        mode: [emacs, vi_normal, vi_insert]
                        event: { send: executehostcommand cmd: (_atuin_search_cmd '--shell-up-key-binding') }
                    }
                )
            )
          '';
      })
    ];

    # Zsh
    programs.zsh = mkIf (builtins.elem "zsh" cfg.shells) {
      enable = true;
      package = pkgs.zsh;

      enableCompletion = true;

      completionInit = /* sh */ ''
        autoload -Uz compinit

        _rix101_zcompdump_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
        _rix101_zcompdump="$_rix101_zcompdump_dir/zcompdump-$HOST-$ZSH_VERSION"
        mkdir -p "$_rix101_zcompdump_dir"

        # Fast path: reuse the dump without compaudit. Fall back to a full
        # compinit when the dump is missing or a Nix profile symlink changed
        # since it was generated.
        _rix101_compinit_flags=(-C)
        if [ ! -s "$_rix101_zcompdump" ]; then
          _rix101_compinit_flags=(-i)
        else
          for _rix101_profile in ''${(z)NIX_PROFILES}; do
            if [ -e "$_rix101_profile" ] && [ "$_rix101_profile" -nt "$_rix101_zcompdump" ]; then
              _rix101_compinit_flags=(-i)
              break
            fi
          done
        fi

        compinit "''${_rix101_compinit_flags[@]}" -d "$_rix101_zcompdump"
        unset _rix101_compinit_flags _rix101_profile _rix101_zcompdump _rix101_zcompdump_dir
      '';

      dotDir = "${config.xdg.configHome}/zsh";

      shellAliases = shellAliases // {
        ls = "${pkgs.lsd}/bin/lsd";
        mkdir = "mkdir -vp";
      };

      history = {
        size = 10000;
        path = "${config.xdg.dataHome}/zsh/history";
      };

      initContent = mkMerge [
        (lib.mkOrder 565 /* sh */ ''
          # - The stock Home Manager `fpath` loop adds the same zsh stdlib
          #   directory once per profile
          # - `compinit` then stats ~1200 files
          #   for every duplicate on cold cache
          # - Keep profile site/vendor completions,
          #   but keep only the real zsh package's stdlib
          fpath+=("${pkgs.zsh}/share/zsh/$ZSH_VERSION/functions")
          typeset -U fpath
          _rix101_fpath=()
          for _rix101_dir in "''${fpath[@]}"; do
            [ -d "$_rix101_dir" ] || continue
            case "$_rix101_dir" in
              */share/zsh/$ZSH_VERSION/functions)
                [ "$_rix101_dir" = "${pkgs.zsh}/share/zsh/$ZSH_VERSION/functions" ] || continue
                ;;
            esac
            _rix101_fpath+=("$_rix101_dir")
          done
          fpath=("''${_rix101_fpath[@]}")
          unset _rix101_dir _rix101_fpath
        '')

        (lib.concatStringsSep "\n" [
          /* sh */ ''
            function take() {
              mkdir -p "''$''\{@''\}" && cd "''$''\{@''\}"
            }
          ''
          (optionalString cfg.atuin /* sh */ ''
            export ATUIN_NOBIND="true"
            source ${zshAtuinInit}/init.zsh
            function zvm_after_init() {
              # bindkey "^r" _atuin_search_widget
              zvm_bindkey viins "^R" _atuin_search_widget
            }
          '')
          (optionalString cfg.zoxide /* sh */ ''
            source ${zshZoxideInit}/init.zsh
          '')
          /* sh */ ''
            # Prevent macOS updates from destroying nix
            if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ] && [ "''$''\{SHLVL''\}" -eq 1 ]; then
              source "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
            fi
          ''
          (optionalString cfg.starship /* sh */ ''
            if [ "''${TERM:-}" != "dumb" ]; then
              source ${zshStarshipInit}/init.zsh
            fi
          '')
          (optionalString cfg.direnv /* sh */ ''
            source ${zshDirenvInit}/init.zsh
          '')
          (optionalString cfg.carapace /* sh */ ''
            source ${zshCarapaceInit}/init.zsh
          '')
          (optionalString cfg.gpg.enable /* sh */ ''
            # Keep `pinentry`'s TTY fresh,
            # but never block prompt rendering on cold gpg/gnupg store paths
            if [ -n "''${TTY:-}" ]; then
              { ${lib.getExe' pkgs.gnupg "gpg-connect-agent"} --quiet updatestartuptty /bye >/dev/null 2>&1 &! }
            fi
          '')
          # cfg.extraConfig
        ])
      ];

      plugins = [
        {
          name = "zsh-nix-shell";
          file = "nix-shell.plugin.zsh";
          src = pkgs.fetchFromGitHub {
            owner = "chisui";
            repo = "zsh-nix-shell";
            rev = "v0.8.0";
            hash = "sha256-Z6EYQdasvpl1P78poj9efnnLj7QQg13Me8x1Ryyw+dM=";
          };
        }
        {
          name = "fast-syntax-highlighting";
          file = "fast-syntax-highlighting.plugin.zsh";
          src = pkgs.fetchFromGitHub {
            owner = "zdharma-continuum";
            repo = "fast-syntax-highlighting";
            rev = "cf318e06a9b7c9f2219d78f41b46fa6e06011fd9";
            hash = "sha256-RVX9ZSzjBW3LpFs2W86lKI6vtcvDWP6EPxzeTcRZua4=";
          };
        }
        {
          name = "zsh-autosuggestions";
          file = "zsh-autosuggestions.plugin.zsh";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-autosuggestions";
            rev = "c3d4e576c9c86eac62884bd47c01f6faed043fc5";
            hash = "sha256-B+Kz3B7d97CM/3ztpQyVkE6EfMipVF8Y4HJNfSRXHtU=";
          };
        }
        {
          name = "zsh-vi-mode";
          file = "zsh-vi-mode.plugin.zsh";
          src = pkgs.fetchFromGitHub {
            owner = "jeffreytse";
            repo = "zsh-vi-mode";
            rev = "287efa19ec492b2f24bb93d1f4eaac3049743a63";
            hash = "sha256-HMfC4s7KW4bO7H6RYzLnSARoFr1Ez89Z2VGONKMpGbw=";
          };
        }
      ];
    };
  };

  meta = {
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
