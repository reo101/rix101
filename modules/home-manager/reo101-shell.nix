{ lib, pkgs, config, ... }:

with lib;
let
  cfg = config.reo101.shell;
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
        extraConfig = mkOption {
          type = types.str;
          description = "Extra zsh config";
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
          (optionals cfg.direnv [
            zoxide
          ])
          (optionals cfg.zoxide [
            direnv
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

        shellAliases = {
          # ll = "ls -l";
          # update = "sudo nixos-rebuild switch";
        };

        history = {
          size = 10000;
          path = "${config.xdg.dataHome}/zsh/history";
        };

        initExtra =
          builtins.concatStringsSep "\n"
            [
              (optionalString cfg.direnv ''
                eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"
              '')
              (optionalString cfg.zoxide ''
                eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
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
              rev = "v0.5.0";
              sha256 = "0za4aiwwrlawnia4f29msk822rj9bgcygw6a8a6iikiwzjjz0g91";
            };
          }
          {
            name = "fast-syntax-highlighting";
            file = "F-Sy-H.plugin.zsh";
            src = pkgs.fetchFromGitHub {
              owner = "zdharma";
              repo = "fast-syntax-highlighting";
              rev = "285d6ce8e1d9c7a70b427c46a4030d43e7a6406b";
              sha256 = "4kma7Sx2RGWa9J4gr+U89ArxpM2/b8H9ytQ2pNCv6is=";
            };
          }
          {
            name = "zsh-vi-mode";
            file = "zsh-vi-mode.plugin.zsh";
            src = pkgs.fetchFromGitHub {
              owner = "jeffreytse";
              repo = "zsh-vi-mode";
              rev = "v0.9.0";
              sha256 = "sha256-KQ7UKudrpqUwI6gMluDTVN0qKpB15PI5P1YHHCBIlpg=";
            };
          }
        ];
      };

      programs.starship = {
        enable = true;

        settings = {
          # Get editor completions based on the config schema
          "$schema" = "https://starship.rs/config-schema.json";

          # Use custom format
          format = ''
            [╭───────┨](bold green)[reo101](bright-white)[@](bold yellow)$hostname[┠───────>](bold green)$status$cmd_duration$git_branch$git_status$git_state$git_commit
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





