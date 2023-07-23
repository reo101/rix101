{ lib, pkgs, config, ... }:

let
  cfg = config.reo101.shell;
  inherit (lib)
    mkEnableOption mkOption types
    mkIf optionals optionalString;
in
{
  imports =
    [
    ];

  options =
    {
      reo101.shell = {
        enable = mkEnableOption "reo101 zsh setup";
        username = mkOption {
          description = "Username to be used in prompt";
          type = types.str;
          default = "${config.home.username}";
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
          description = "Flake path (used for `rebuild` command)";
          type = types.str;
          default = "${config.xdg.configHome}/rix101";
        };
        extraConfig = mkOption {
          description = "Extra zsh config";
          type = types.str;
          default = ''
          '';
        };
      };
    };

  config =
    mkIf cfg.enable {
      home.packages = with pkgs;
        builtins.concatLists [
          [
            zsh
            starship
          ]
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

      programs.direnv = mkIf cfg.direnv {
        enable = true;

        nix-direnv = {
          enable = true;
        };
      };

      programs.zsh = {
        enable = true;
        enableCompletion = true;
        dotDir = ".config/zsh";

        shellAliases = {
          ls = "${pkgs.lsd}/bin/lsd";
          cp = "${pkgs.advcpmv}/bin/advcp -rvi";
          mv = "${pkgs.advcpmv}/bin/advmv -vi";
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
                rebuild () {
                  ${
                    let
                      inherit (lib.strings) hasInfix;
                    in
                    if hasInfix "nixos" pkgs.system then
                      "sudo --validate && sudo nixos-rebuild"
                    else if hasInfix "darwin" pkgs.system then
                      "darwin-rebuild"
                    else if "aarch64-linux" == pkgs.system then
                      "nix-on-droid"
                    else
                      "home-manager"
                  } --flake ${cfg.flakePath} ''$''\{1:-switch''\} |& nix run nixpkgs#nix-output-monitor
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
              (optionalString cfg.zoxide ''
                eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"
              '')
              cfg.extraConfig
            ];

        plugins = [
          {
            name = "zsh-nix-shell";
            file = "nix-shell.plugin.zsh";
            src = pkgs.fetchFromGitHub {
              owner = "chisui";
              repo = "zsh-nix-shell";
              rev = "v0.7.0";
              sha256 = "sha256-oQpYKBt0gmOSBgay2HgbXiDoZo5FoUKwyHSlUrOAP5E=";
            };
          }
          {
            name = "fast-syntax-highlighting";
            file = "fast-syntax-highlighting.plugin.zsh";
            src = pkgs.fetchFromGitHub {
              owner = "zdharma-continuum";
              repo = "fast-syntax-highlighting";
              rev = "cf318e06a9b7c9f2219d78f41b46fa6e06011fd9";
              sha256 = "sha256-RVX9ZSzjBW3LpFs2W86lKI6vtcvDWP6EPxzeTcRZua4=";
            };
          }
          {
            name = "zsh-autosuggestions";
            file = "zsh-autosuggestions.plugin.zsh";
            src = pkgs.fetchFromGitHub {
              owner = "zsh-users";
              repo = "zsh-autosuggestions";
              rev = "a411ef3e0992d4839f0732ebeb9823024afaaaa8";
              sha256 = "sha256-KLUYpUu4DHRumQZ3w59m9aTW6TBKMCXl2UcKi4uMd7w=";
            };
          }
          {
            name = "zsh-vi-mode";
            file = "zsh-vi-mode.plugin.zsh";
            src = pkgs.fetchFromGitHub {
              owner = "jeffreytse";
              repo = "zsh-vi-mode";
              rev = "1bda23100e8d140a19be0eed67395c64f6a6074c";
              sha256 = "sha256-3arAa5EBG+U9cCauChX9K0KF3hkd+t04/trlWKk/gOw=";
            };
          }
        ];
      };

      home.file.".config/atuin/config.toml" = mkIf cfg.atuin {
        text = ''
          ## where to store your database, default is your system data directory
          ## mac: ~/Library/Application Support/com.elliehuxtable.atuin/history.db
          ## linux: ~/.local/share/atuin/history.db
          # db_path = "~/.history.db"

          ## where to store your encryption key, default is your system data directory
          # key_path = "~/.key"

          ## where to store your auth session token, default is your system data directory
          # session_path = "~/.key"

          ## date format used, either "us" or "uk"
          # dialect = "us"

          ## enable or disable automatic sync
          auto_sync = true

          ## enable or disable automatic update checks
          update_check = false

          ## address of the sync server
          sync_address = "https://naboo.qtrp.org/atuin"

          ## how often to sync history. note that this is only triggered when a command
          ## is ran, so sync intervals may well be longer
          ## set it to 0 to sync after every command
          sync_frequency = "1m"

          ## which search mode to use
          ## possible values: prefix, fulltext, fuzzy, skim
          # search_mode = "fuzzy"

          ## which filter mode to use
          ## possible values: global, host, session, directory
          filter_mode = "global"

          # ## which filter mode to use when atuin is invoked from a shell up-key binding
          # ## the accepted values are identical to those of "filter_mode"
          # ## leave unspecified to use same mode set in "filter_mode"
          # filter_mode_shell_up_keybinding = "session"

          ## which style to use
          ## possible values: auto, full, compact
          # style = "auto"

          ## the maximum number of lines the interface should take up
          ## set it to 0 to always go full screen
          # inline_height = 0

          ## enable or disable showing a preview of the selected command
          ## useful when the command is longer than the terminal width and is cut off
          # show_preview = false

          ## what to do when the escape key is pressed when searching
          ## possible values: return-original, return-query
          # exit_mode = "return-original"

          ## possible values: emacs, subl
          # word_jump_mode = "emacs"

          ## characters that count as a part of a word
          # word_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

          ## number of context lines to show when scrolling by pages
          # scroll_context_lines = 1

          ## prevent commands matching any of these regexes from being written to history.
          ## Note that these regular expressions are unanchored, i.e. if they don't start
          ## with ^ or end with $, they'll match anywhere in the command.
          ## For details on the supported regular expression syntax, see
          ## https://docs.rs/regex/latest/regex/#syntax
          # history_filter = [
          #   "^secret-cmd",
          #   "^innocuous-cmd .*--secret=.+"
          # ]
        '';
      };

      programs.starship = {
        enable = true;

        settings = {
          # Get editor completions based on the config schema
          "$schema" = "https://starship.rs/config-schema.json";

          # Use custom format
          format = ''
            [╭───────┨](bold green)[${cfg.username}](bright-white)[@](bold yellow)$hostname[┠───────>](bold green)$status$cmd_duration$git_branch$git_status$git_state$git_commit
            [│](bold green)$time$jobs: $directory$package
            [╰─](bold green)$character
          '';

          # ${custom.local}\
          # ${custom.local_root}\
          # ${custom.ssh}\
          # ${custom.ssh_root}\

          add_newline = true;

          character = {
            success_symbol = "[→](bold green)";
            error_symbol = "[→](red)";
          };

          git_branch = {
            symbol = "🌱 ";
            truncation_length = 15;
            truncation_symbol = "…"; # …
          };

          git_commit = {
            commit_hash_length = 6;
            tag_symbol = "🔖 ";
          };

          git_state = {
            format = "[\($state( $progress_current of $progress_total)\)]($style) ";
            cherry_pick = "[🍒 PICKING](bold red)";
          };

          git_status = {
            # conflicted = "🏳";
            # ahead = "🏎💨";
            # behind = "😰";
            # diverged = "😵";
            # untracked = "🤷‍";
            # stashed = "📦";
            # modified = "📝";
            # staged = '[++\($count\)](green)';
            # renamed = "👅";
            # deleted = "🗑";
            format = "[\\[$all_status$ahead_behind\\]]($style) ";
            conflicted = "=[\($count\)](green) ";
            ahead = "⇡[\($count\)](green) ";
            behind = "⇣[\($count\)](green) ";
            diverged = "⇕[\($count\)](green) ";
            untracked = "?[\($count\)](green) ";
            stashed = "$[\($count\)](green) ";
            modified = "![\($count\)](green) ";
            staged = "+[\($count\)](green) ";
            renamed = "»[\($count\)](green) ";
            deleted = "✘[\($count\)](green) ";
          };

          status = {
            style = "bg:blue fg:red";
            symbol = "🔴";
            format = "[\[$symbol $common_meaning$signal_name$maybe_int\]]($style) ";
            map_symbol = true;
            disabled = false;
          };

          time = {
            disabled = false;
            format = "🕙[$time]($style) ";
            # format = '🕙[\[ $time \]]($style) ';
            time_format = "%T";
            utc_time_offset = "+3";
            # time_range = "10:00:00-14:00:00";
          };

          cmd_duration = {
            min_time = 2000; # miliseconds
            # show_notifications = true;
            min_time_to_notify = 45000; # miliseconds
            format = "took [$duration](bold yellow) ";
          };

          hostname = {
            ssh_only = false;
            format = "[$hostname](bold fg:#CC59B0)";
            disabled = false;
          };

          username = {
            disabled = false;
            style_user = "white bold";
            style_root = "red bold";
            format = "[$user]($style)[@](bold yellow)";
            show_always = true;
          };

          directory = {
            read_only = "🔒";
            read_only_style = "bold white";
            style = "fg:#A7F3E4";
            truncate_to_repo = false;
            truncation_length = 5;
            truncation_symbol = "…/";
            home_symbol = "🏡";
            format = "[$read_only]($read_only_style)[$path]($style) ";
          };

          directory.substitutions = {
            ".config" = " ";
            "nvim" = "";
            "emacs" = "𝓔";
            "doom" = "𝓔";
            "Projects" = "💻";
            "FMI" = "🏫";
            "Home" = "🏠";
            "CPP" = "";
            "Java" = "";
            "Python" = "";
          };

          # Language Environments
          package = {
            style = "bold fg:#5E5E5E";
          };

          python = {
            style = "bold fg:#5E5E5E";
            symbol = "[](bold yellow) ";
          };

          nodejs = {
            style = "bold fg:#5E5E5E";
            symbol = "[⬢](bold green) ";
          };

          # Custom
          jobs = {
            format = "[ $symbol$number ]($style)";
            style = "bg:#587744 fg:bright-white";
            symbol = "⚙";
          };

          custom.local = {
            shell = [ "zsh" "-d" "-f" ];
            when = '' [ [ -z "$SSH_CLIENT" ] ] && [ [ `whoami` != "root" ] ] '';
            format = "[$symbol$output]($style)[@](bold yellow)";
            command = "whoami";
            style = "fg:bright-white";
            symbol = "";
          };

          custom.local_root = {
            shell = [ "zsh" "-d" "-f" ];
            when = '' [ [ -z "$SSH_CLIENT" ] ] && [ [ `whoami` == "root" ] ] '';
            format = "[ $output ]($style)[@](bold yellow)";
            command = "whoami";
            style = "bg:red fg:bright-white";
          };

          custom.ssh = {
            shell = [ "zsh" "-d" "-f" ];
            when = '' [ [ -n "$SSH_CLIENT" ] ] && [ [ `whoami` != "root" ] ] '';
            format = "[ $symbol$output ]($style)[@](bold yellow)";
            command = "whoami";
            style = "bg:blue fg:bright-white";
            # style = "bg:#FD7208 fg:bright-white";
            symbol = "⌁";
          };

          custom.ssh_root = {
            shell = [ "zsh" "-d" "-f" ];
            when = '' [ [ -n "$SSH_CLIENT" ] ] && [ [ `whoami` == "root" ] ] '';
            format = "[ $symbol$output ]($style)[@](bold yellow)";
            command = "whoami";
            style = "bg:red fg:bright-white";
            symbol = "⌁";
          };
        };
      };
    };

  meta = {
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
