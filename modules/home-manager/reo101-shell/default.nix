{ lib, pkgs, config, ... }:

let
  cfg = config.reo101.shell;

  inherit (lib)
    mkEnableOption mkOption types
    mkIf optionals optionalString
    mkMerge;

  shellAliases = {
    cp = "${pkgs.advcpmv}/bin/advcp -rvi";
    mv = "${pkgs.advcpmv}/bin/advmv -vi";
    rebuild =
      let
        rebuild_script = pkgs.writeShellScript "rebuild" ''
          ${
            let
              inherit (lib.strings)
                hasInfix;
              inherit (pkgs.hostPlatform)
                isx86_64 isAarch64
                isLinux isDarwin;
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
            if cfg.hostname != null
            then "${cfg.flakePath}#${cfg.hostname}"
            else "${cfg.flakePath}"
          } ''$''\{1:-switch''\} "''$''\{@:2''\}" # |& nix run nixpkgs#nix-output-monitor
        '';
      in
      "${rebuild_script}";
  };
in
{
  imports =
    [
    ];

  options =
    {
      reo101.shell = {
        enable = mkEnableOption "reo101 shell setup";
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
          default = [ "nushell" "zsh" ];
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
        direnv = mkOption {
          description = "Integrate with direnv";
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

  config =
    mkIf cfg.enable {
      home.packages = with pkgs;
        builtins.concatLists [
          (builtins.map
            (lib.flip builtins.getAttr pkgs)
            cfg.shells)
          (optionals cfg.starship [
            starship
          ])
          (optionals cfg.atuin [
            atuin
          ])
          (optionals cfg.direnv [
            direnv
          ])
          (optionals cfg.zoxide [
            zoxide
          ])
        ];

      # Atuin
      home.file."${config.xdg.configHome}/atuin/config.toml" = mkIf cfg.atuin {
        # TODO: use pkgs.substituteAll
        text = import ./atuin.nix {
          keyPath = "${config.xdg.dataHome}/atuin/key";
        };
      };

      # Direnv
      programs.direnv = mkIf cfg.direnv {
        enable = true;

        enableNushellIntegration = builtins.elem "nushell" cfg.shells;
        enableZshIntegration = builtins.elem "zsh" cfg.shells;

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
      };

      # Zoxide
      programs.zoxide = mkIf cfg.zoxide {
        enable = true;

        package = pkgs.zoxide;

        enableNushellIntegration = builtins.elem "nushell" cfg.shells;
        enableZshIntegration = builtins.elem "zsh" cfg.shells;
      };

      # GnuPG
      services.gpg-agent = {
        enableNushellIntegration = builtins.elem "nushell" cfg.shells;
        enableZshIntegration = builtins.elem "zsh" cfg.shells;
      };

      # Shell
      home.sessionVariables = {
        SHELL =
          let
            shellPackage = builtins.getAttr (builtins.head cfg.shells) pkgs;
          in
          "${shellPackage}/${shellPackage.shellPath}";
      };

      # Nushell
      programs.nushell = mkMerge [
        (mkIf (builtins.elem "nushell" cfg.shells) {
          enable = true;

          package = pkgs.nushell;

          configFile.source = ./nushell/config.nu;
          envFile.source    = ./nushell/env.nu;
          loginFile.source  = ./nushell/login.nu;

          inherit shellAliases;

          environmentVariables = { };
        })
        (mkIf cfg.atuin {
          extraEnv = ''
            let atuin_cache = "${config.xdg.cacheHome}/atuin"
            if not ($atuin_cache | path exists) {
                mkdir $atuin_cache
            }
            ${pkgs.atuin}/bin/atuin init nu | save --force ${config.xdg.cacheHome}/atuin/init.nu
          '';

          extraConfig = ''
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

        dotDir = ".config/zsh";

        shellAliases = shellAliases // {
          ls = "${pkgs.lsd}/bin/lsd";
          mkdir = "mkdir -vp";
        };

        history = {
          size = 10000;
          path = "${config.xdg.dataHome}/zsh/history";
        };

        initExtra =
          builtins.concatStringsSep "\n"
            [
              ''
                function take() {
                  mkdir -p "''$''\{@''\}" && cd "''$''\{@''\}"
                }
              ''
              (optionalString cfg.atuin ''
                export ATUIN_NOBIND="true"
                eval "$(${pkgs.atuin}/bin/atuin init zsh)"
                function zvm_after_init() {
                  # bindkey "^r" _atuin_search_widget
                  zvm_bindkey viins "^R" _atuin_search_widget
                }
              '')
              # NOTE: done by `programs.direnv`
              # (optionalString cfg.direnv ''
              #   eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
              # '')
              # NOTE: done by `programs.zoxide`
              # (optionalString cfg.zoxide ''
              #   eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"
              # '')
              ''
                # Prevent macOS updates from destroying nix
                if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ] && [ "''$''\{SHLVL''\}" -eq 1 ]; then
                  source "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
                fi
              ''
              # cfg.extraConfig
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
