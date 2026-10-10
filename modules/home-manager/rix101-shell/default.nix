moduleArguments@{
  lib,
  pkgs,
  config,
  ...
}:

let
  meta = moduleArguments.meta or (config._module.args.meta or { });
  cfg = config.rix101.shell;

  inshellisenseAvailable =
    pkgs ? inshellisense && lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.inshellisense;
  carapaceBridges = lib.concatStringsSep "," (
    lib.optionals inshellisenseAvailable [ "inshellisense" ]
    ++ [
      "carapace"
      "zsh"
      "fish"
      "bash"
    ]
  );
  carapaceBridgePackages = [
    pkgs.zsh
    pkgs.fish
    pkgs.bashInteractive
  ]
  ++ lib.optionals inshellisenseAvailable [ pkgs.inshellisense ];
  carapacePackage = config.programs.carapace.finalPackage;

  # Cache dynamic shell init snippets at build time. Spawning helper binaries
  # just to print mostly-static zsh is very visible on cold or slow filesystems.
  # Keep the generated files in the Nix store (not XDG_CACHE_HOME) so deleting
  # user caches never breaks shell startup. Syntax-check every snippet while
  # building so upstream init-output changes fail early.
  zshCachedInit =
    name: nativeBuildInputs: script:
    pkgs.runCommand "rix101-shell-zsh-${name}-init"
      {
        nativeBuildInputs = [ config.programs.zsh.package ] ++ nativeBuildInputs;
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

    # Disable generated bindings before caching, not via a runtime-only variable.
    ${lib.getExe config.programs.atuin.package} init zsh \
      --disable-ctrl-r --disable-up-arrow --disable-ai > "$out/init.zsh"
    substituteInPlace "$out/init.zsh" \
      --replace-fail 'atuin ' '${lib.getExe config.programs.atuin.package} '
  '';

  zshCarapaceInit = zshCachedInit "carapace" [ ] ''
    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$TMPDIR/config"
    export CARAPACE_BRIDGES=${lib.escapeShellArg carapaceBridges}
    mkdir -p "$HOME" "$XDG_CONFIG_HOME"

    ${lib.getExe carapacePackage} _carapace zsh > "$out/init.zsh"
    substituteInPlace "$out/init.zsh" \
      --replace-fail "$XDG_CONFIG_HOME/carapace" '${config.xdg.configHome}/carapace'
    substituteInPlace "$out/init.zsh" \
      --replace-fail 'xargs carapace ' 'xargs ${lib.getExe carapacePackage} '
  '';

  zshDirenvInit = zshCachedInit "direnv" [ ] ''
    ${lib.getExe config.programs.direnv.package} hook zsh > "$out/init.zsh"
  '';

  zshStarshipInit = zshCachedInit "starship" [ ] ''
    ${lib.getExe config.programs.starship.package} init zsh > "$out/init.zsh"
  '';

  zshZoxideInit = zshCachedInit "zoxide" [ ] ''
    ${lib.getExe config.programs.zoxide.package} init zsh > "$out/init.zsh"
    substituteInPlace "$out/init.zsh" \
      --replace-fail '\command zoxide' '\command ${lib.getExe config.programs.zoxide.package}'
  '';

  starshipNuConfig =
    pkgs.runCommand "starship-nushell.toml"
      {
        nativeBuildInputs = [ pkgs.yq ];
      }
      ''
        tomlq -t '.character.disabled = true' ${
          lib.escapeShellArg (
            builtins.toString config.home.file.${config.programs.starship.configPath}.source
          )
        } > "$out"
      '';

  rebuildCommand =
    if cfg.rebuildBackend == "nixos" then
      let
        nixForRebuild = lib.infuse pkgs.custom.nix-enraged {
          __input.monitored.__assign = true;
        };
        nixosRebuild = lib.infuse pkgs.nixos-rebuild-ng {
          __input.nix.__assign = nixForRebuild;
        };
      in
      "sudo --validate && ${lib.getExe nixosRebuild} --no-reexec --sudo"
    else
      {
        nix-darwin = "darwin-rebuild";
        nix-on-droid = "nix-on-droid";
        home-manager = "home-manager";
      }
      .${cfg.rebuildBackend};

  rebuildScript = pkgs.writeShellScript "rebuild" ''
    ${rebuildCommand} --flake ${
      lib.escapeShellArg (
        cfg.flakePath + lib.optionalString (cfg.rebuildTarget != null) "#${cfg.rebuildTarget}"
      )
    } "''${1:-switch}" "''${@:2}"
  '';

  shellAliases.rebuild = "${rebuildScript}";

  migrationArguments =
    lib.optionals
      (cfg.atuin && cfg.atuinDataDir != null && cfg.atuinDataDir != "${config.xdg.dataHome}/atuin")
      [
        "--atuin-source"
        "${config.xdg.dataHome}/atuin"
        "--atuin-destination"
        cfg.atuinDataDir
      ]
    ++ lib.optionals (cfg.historyPath != "${config.xdg.dataHome}/zsh/history") [
      "--history-source"
      "${config.xdg.dataHome}/zsh/history"
      "--history-destination"
      cfg.historyPath
    ];
  migrateState = pkgs.writeShellApplication {
    name = "migrate-shell-state";
    text = ''
      # Explicit source/destination pairs select components for recovery or manual use.
      for argument in "$@"; do
        case "$argument" in
          --atuin-source*|--atuin-destination*|--history-source*|--history-destination*)
            exec ${lib.getExe pkgs.python3} ${./migrate-state.py} "$@"
            ;;
        esac
      done
      exec ${lib.getExe pkgs.python3} ${./migrate-state.py} ${lib.escapeShellArgs migrationArguments} "$@"
    '';
  };
in
{
  imports = [
    (lib.mkRenamedOptionModule [ "rix101" "shell" "hostname" ] [ "rix101" "shell" "rebuildTarget" ])
  ];

  options = {
    rix101.shell = {
      enable = lib.mkEnableOption "rix101 shell setup";
      rebuildBackend = lib.mkOption {
        type = lib.types.enum [
          "nixos"
          "nix-darwin"
          "nix-on-droid"
          "home-manager"
        ];
        default = meta.configurationType or "home-manager";
        description = "Rebuild backend, derived from the configuration generator.";
      };
      rebuildTarget = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = meta.hostname or null;
        description = "Flake configuration attribute for rebuild. Defaults to the machine hostname.";
      };
      shells = lib.mkOption {
        type = lib.types.addCheck (lib.types.listOf (
          lib.types.enum [
            "nushell"
            "zsh"
          ]
        )) (shells: shells != [ ]);
        description = "Nonempty list of shells to configure. The first sets $SHELL, not the account login shell.";
        default = [
          "nushell"
          "zsh"
        ];
      };
      starship = lib.mkOption {
        type = lib.types.bool;
        description = "Use starship prompt";
        default = true;
      };
      atuin = lib.mkOption {
        type = lib.types.bool;
        description = "Integrate with atuin";
        default = true;
      };
      atuinDataDir = lib.mkOption {
        description = "Directory for Atuin data files.";
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      carapace = lib.mkOption {
        type = lib.types.bool;
        description = "Integrate with carapace";
        default = true;
      };
      direnv = lib.mkOption {
        type = lib.types.bool;
        description = "Integrate with direnv";
        default = true;
      };
      gpg = {
        enable = lib.mkEnableOption "GPG setup";
        pinentryPackage = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          example = lib.literalExpression "pkgs.pinentry-gnome3";
          default = null;
        };
      };
      zellij = lib.mkOption {
        type = lib.types.bool;
        description = "Integrate with zellij";
        default = true;
      };
      zoxide = lib.mkOption {
        type = lib.types.bool;
        description = "Integrate with zoxide";
        default = true;
      };
      historyPath = lib.mkOption {
        description = "Path to the zsh history file.";
        type = lib.types.str;
        default = "${config.xdg.dataHome}/zsh/history";
      };
      flakePath = lib.mkOption {
        type = lib.types.str;
        description = "Flake path (for `rebuild`)";
        default = "${config.xdg.configHome}/rix101";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      lib.optionals cfg.gpg.enable [
        pkgs.yubikey-manager
        pkgs.yubikey-personalization
      ]
      # gpg-agent references the package but does not install its CLI.
      ++ lib.optionals (cfg.gpg.enable && !config.programs.gpg.enable) [ config.programs.gpg.package ]
      ++ lib.optionals (migrationArguments != [ ]) [ migrateState ];

    programs.atuin = lib.mkIf cfg.atuin {
      enable = true;
      enableNushellIntegration = builtins.elem "nushell" cfg.shells;
      # HM still runs `atuin init zsh` at startup; retain the compiled store init.
      enableZshIntegration = false;
      enableBashIntegration = false;
      enableFishIntegration = false;
      settings = import ./atuin.nix {
        inherit lib;
        dataDir = cfg.atuinDataDir;
        keyPath =
          if cfg.atuinDataDir != null then "${cfg.atuinDataDir}/key" else "${config.xdg.dataHome}/atuin/key";
      };
    };

    # Carapace
    programs.carapace = lib.mkIf cfg.carapace {
      enable = true;
      enableNushellIntegration = builtins.elem "nushell" cfg.shells;
      enableZshIntegration = false;
      environment.CARAPACE_BRIDGES = carapaceBridges;
      # The Nix completer assumes legacy channel programs.sqlite databases.
      environment.CARAPACE_EXCLUDES = "nix";
      extraPackages = carapaceBridgePackages;
    };

    # Direnv
    programs.direnv = lib.mkIf cfg.direnv {
      enable = true;

      enableNushellIntegration = builtins.elem "nushell" cfg.shells;
      enableZshIntegration = false;

      nix-direnv = {
        enable = true;
      };
    };

    # Starship
    programs.starship = lib.mkIf cfg.starship {
      enable = true;

      package = import ./starship-package.nix { inherit pkgs; };

      settings = import ./starship.nix {
        inherit lib;
        schema = config.programs.starship.package.jsonschema.config;
      };

      enableNushellIntegration = builtins.elem "nushell" cfg.shells;
      enableZshIntegration = false;
    };

    # Zellij
    programs.zellij = lib.mkIf cfg.zellij {
      enable = true;

      # Do not attach a session inside every interactive shell.
      enableZshIntegration = false;
    };

    # Zoxide
    programs.zoxide = lib.mkIf cfg.zoxide {
      enable = true;

      enableNushellIntegration = builtins.elem "nushell" cfg.shells;
      enableZshIntegration = false;
    };

    # GnuPG
    services.gpg-agent = lib.mkMerge [
      (lib.mkIf cfg.gpg.enable (
        let
          ttl = 2 * 60 * 60;
        in
        {
          enable = true;
          defaultCacheTtl = ttl;
          maxCacheTtl = ttl;
          defaultCacheTtlSsh = ttl;
          maxCacheTtlSsh = ttl;
          pinentry.package =
            if cfg.gpg.pinentryPackage != null then
              cfg.gpg.pinentryPackage
            else if pkgs.stdenv.hostPlatform.isDarwin then
              pkgs.pinentry_mac
            else if meta.gui or false then
              pkgs.pinentry-qt
            else
              pkgs.pinentry-tty;
          enableSshSupport = true;
          # WARN: GnuPG deprecated `sshcontrol` in favor of the
          # `Use-for-ssh` key attribute. Keep this until Home Manager
          # exposes a declarative replacement for `sshKeys`.
          sshKeys = [
            # NOTE: will mainly be using `YubiKey`s, this is a fallback
            "CFDE97EDC2FDB2FD27020A084F1E3F40221BAFE7"
          ];
        }
      ))
      (lib.mkIf config.services.gpg-agent.enable {
        # Replace HM's synchronous terminal update, not its SSH socket selection.
        enableNushellIntegration = lib.mkIf (builtins.elem "nushell" cfg.shells) (lib.mkDefault false);
        enableZshIntegration = lib.mkIf (builtins.elem "zsh" cfg.shells) (lib.mkDefault false);
      })
    ];

    # WARN: `disable-ccid` routes GnuPG's smartcard access through PC/SC
    # (pcscd) instead of GnuPG's own internal CCID (libusb) driver. Do NOT
    # remove this: that internal driver and `age-plugin-yubikey` (a pcsc
    # client) both try to claim the YubiKey's single CCID interface, the loser
    # gets "Can't claim interface: LIBUSB_ERROR_BUSY" / "No such device", and
    # the only cure is replugging. A single PC/SC owner serializes both.
    home.file."${config.programs.gpg.homedir}/scdaemon.conf" = lib.mkIf cfg.gpg.enable {
      text = ''
        disable-ccid
      '';
    };

    # Shell
    home.sessionVariables = lib.mkMerge [
      {
        SHELL =
          let
            shellPackage = config.programs.${builtins.head cfg.shells}.package;
          in
          "${shellPackage}${shellPackage.shellPath}";
        EDITOR = "nvim";
        MANPAGER = "nvim +Man!";
      }
      (lib.mkIf cfg.carapace {
        CARAPACE_BRIDGES = carapaceBridges;
      })
      (lib.mkIf cfg.direnv {
        # Deliberately suppress slow-load warnings; environment loading still runs normally.
        DIRENV_WARN_TIMEOUT = "0";
      })
    ];

    # Nushell
    programs.nushell = lib.mkIf (builtins.elem "nushell" cfg.shells) {
      enable = true;
      configFile.text = ''
        const gitignore_move_program = "${lib.getExe' pkgs.coreutils "mv"}"
        ${builtins.readFile ./nushell/config.nu}
      '';
      envFile.source = ./nushell/env.nu;
      inherit shellAliases;
      extraConfig = lib.mkMerge [
        (lib.mkIf (config.services.gpg-agent.enable && !config.services.gpg-agent.enableNushellIntegration)
          ''
            let terminal = (do { ${lib.getExe' pkgs.coreutils "tty"} } | complete)
            if $terminal.exit_code == 0 {
              $env.GPG_TTY = ($terminal.stdout | str trim)
              job spawn {
                ${lib.getExe' config.programs.gpg.package "gpg-connect-agent"} --quiet updatestartuptty /bye | complete | ignore
              } | ignore
            }
          ''
        )
        (lib.mkIf cfg.starship (
          lib.mkAfter ''
            # HM's Starship init resets indicators. Nu owns its vi-mode character.
            $env.STARSHIP_CONFIG = "${starshipNuConfig}"
            ${builtins.readFile ./nushell/env.nu}
            ${lib.optionalString ((config.programs.starship.settings.right_format or "") == "") ''
              # Do not launch another Starship process for an empty right prompt.
              $env.PROMPT_COMMAND_RIGHT = ""
            ''}
          ''
        ))
      ];
    };

    # Zsh
    programs.zsh = lib.mkIf (builtins.elem "zsh" cfg.shells) {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      fastSyntaxHighlighting.enable = true;

      # Inline the file: no extra source lookup on the startup path.
      completionInit = builtins.readFile ./zsh/completion-init.zsh;

      dotDir = "${config.xdg.configHome}/zsh";

      shellAliases = shellAliases // {
        ls = "${pkgs.lsd}/bin/lsd";
        mkdir = "mkdir -vp";
      };

      history = {
        size = 10000;
        path = cfg.historyPath;
        ignoreSpace = true;
      };

      initContent = lib.mkMerge [
        (lib.mkOrder 565 /* sh */ ''
          # - The stock Home Manager `fpath` loop adds the same zsh stdlib
          #   directory once per profile
          # - `compinit` then stats ~1200 files
          #   for every duplicate on cold cache
          # - Keep profile site/vendor completions,
          #   but keep only the real zsh package's stdlib
          fpath+=("${config.programs.zsh.package}/share/zsh/$ZSH_VERSION/functions")
          _rix101_fpath=()
          for _rix101_dir in "''${fpath[@]}"; do
            [ -d "$_rix101_dir" ] || continue
            case "$_rix101_dir" in
              */share/zsh/$ZSH_VERSION/functions)
                [ "$_rix101_dir" = "${config.programs.zsh.package}/share/zsh/$ZSH_VERSION/functions" ] || continue
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
          (lib.optionalString cfg.atuin /* sh */ ''
            source ${zshAtuinInit}/init.zsh
            function zvm_after_init() {
              zvm_bindkey viins "^R" atuin-search-viins
            }
          '')
          /* sh */ ''
            # vi-mode's lazy initialization replaces autosuggestion widgets.
            zvm_after_init_commands+=(_zsh_autosuggest_bind_widgets)
          ''
          (lib.optionalString cfg.zoxide /* sh */ ''
            source ${zshZoxideInit}/init.zsh
          '')
          /* sh */ ''
            # Prevent macOS updates from destroying nix
            if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ] && [ "''$''\{SHLVL''\}" -eq 1 ]; then
              source "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
            fi
          ''
          (lib.optionalString cfg.starship /* sh */ ''
            if [ "''${TERM:-}" != "dumb" ]; then
              # Reset the shell-specific config when entering Zsh from Nushell.
              export STARSHIP_CONFIG=${lib.escapeShellArg config.programs.starship.configPath}
              source ${zshStarshipInit}/init.zsh
              ${lib.optionalString ((config.programs.starship.settings.right_format or "") == "") ''
                # An empty right format does not need a second prompt process.
                RPROMPT=""
              ''}
            fi
          '')
          (lib.optionalString cfg.direnv /* sh */ ''
            source ${zshDirenvInit}/init.zsh
          '')
          (lib.optionalString cfg.carapace /* sh */ ''
            source ${zshCarapaceInit}/init.zsh
          '')
          (lib.optionalString cfg.direnv /* sh */ ''
            # Run after direnv has exported the current environment. Reapply
            # integrations whose completion definitions/widgets compinit resets.
            _rix101_completion_refresh() {
              if _rix101_completion_synchronize || [[ $? == 2 ]]; then
                # Restore integrations even if compinit failed after clearing mappings.
                # Carapace init prepends its user bin directory; keep that
                # repeated prepend local while restoring its definitions.
                local PATH="$PATH"
                ${lib.optionalString cfg.carapace "source ${zshCarapaceInit}/init.zsh"}
                (( $+functions[_zsh_autosuggest_bind_widgets] )) && _zsh_autosuggest_bind_widgets
              fi
              return 0
            }
            autoload -Uz add-zsh-hook
            add-zsh-hook precmd _rix101_completion_refresh
          '')
          (lib.optionalString
            (config.services.gpg-agent.enable && !config.services.gpg-agent.enableZshIntegration)
            /* sh */ ''
              # Export the current TTY before scheduling the nonblocking agent update.
              if [ -n "''${TTY:-}" ]; then
                export GPG_TTY="$TTY"
                { ${lib.getExe' config.programs.gpg.package "gpg-connect-agent"} --quiet updatestartuptty /bye >/dev/null 2>&1 &! }
              fi
            ''
          )
        ])
      ];

      plugins = [
        {
          name = "zsh-nix-shell";
          file = "share/zsh-nix-shell/nix-shell.plugin.zsh";
          src = pkgs.zsh-nix-shell;
        }
        {
          name = "zsh-vi-mode";
          file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
          src = pkgs.zsh-vi-mode;
        }
      ];
    };
  };

  meta = {
    maintainers = [ lib.maintainers.reo101 ];
  };
}
