{ inputs, lib, config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    username = "nix-on-droid";
    # username = "reo101";
    homeDirectory = "/data/data/com.termux.nix/files/home";
    stateVersion = "22.05";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # neovim
    # clang
    gcc

    diffutils
    findutils
    utillinux
    tzdata
    hostname
    man
    ncurses
    gnugrep
    gnupg
    gnused
    gnutar
    bzip2
    gzip
    xz
    zip
    unzip

    direnv
    nix-direnv

    # Bling
    onefetch
    neofetch

    # Utils
    ripgrep

    # Passwords
    pass
    passExtensions.pass-otp

    # Dhall
    dhall
    dhall-lsp-server

    # Zig
    zigpkgs.master
    inputs.zls-overlay.packages.aarch64-linux.default
  ];

  nixpkgs = {
    overlays = [
      inputs.neovim-nightly-overlay.overlay
      inputs.zig-overlay.overlays.default
      # inputs.zls-overlay.???
    ];

    config.allowUnfree = true;
  };

  programs.neovim = {
    enable = true;
    package = pkgs.neovim-nightly;
    # defaultEditor = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    withPython3 = false;
    withNodeJs = false;
    withRuby = false;

    # neovimRcContent = "";

    extraPackages = with pkgs; [
        tree-sitter
        rnix-lsp
        # sumneko-lua-language-server
        # stylua
        # texlab
        # rust-analyzer
    ];
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    defaultKeymap = "viins";

    shellAliases = {
      # ll = "ls -l";
      # update = "sudo nixos-rebuild switch";
    };

    history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
    };

	  initExtra = ''
      eval "$(direnv hook zsh)"
    '';

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
    ];
  };

  programs.starship = {
    enable = true;

    settings = {
      # Get editor completions based on the config schema
      "$schema" = "https://starship.rs/config-schema.json";

      # Use custom format
      format = ''
        [╭───────┨](bold green)[nix-on-droid](bright-white)[@](bold yellow)$hostname[┠───────>](bold green)$status$cmd_duration$git_branch$git_status$git_state$git_commit
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
        shell = ["zsh" "-d" "-f"];
        when = ''[[ -z "$SSH_CLIENT" ]] && [[ `whoami` != "root" ]]'';
        format = "[$symbol$output]($style)[@](bold yellow)";
        command = "whoami";
        style = "fg:bright-white";
        symbol = "";
      };

      custom.local_root = {
        shell = ["zsh" "-d" "-f"];
        when = ''[[ -z "$SSH_CLIENT" ]] && [[ `whoami` == "root" ]]'';
        format = "[ $output ]($style)[@](bold yellow)";
        command = "whoami";
        style = "bg:red fg:bright-white";
      };

      custom.ssh = {
        shell = ["zsh" "-d" "-f"];
        when = ''[[ -n "$SSH_CLIENT" ]] && [[ `whoami` != "root" ]]'';
        format = "[ $symbol$output ]($style)[@](bold yellow)";
        command = "whoami";
        style = "bg:blue fg:bright-white";
        # style = "bg:#FD7208 fg:bright-white";
        symbol = "⌁";
      };

      custom.ssh_root = {
        shell = ["zsh" "-d" "-f"];
        when = ''[[ -n "$SSH_CLIENT" ]] && [[ `whoami` == "root" ]]'';
        format = "[ $symbol$output ]($style)[@](bold yellow)";
        command = "whoami";
        style = "bg:red fg:bright-white";
        symbol = "⌁";
      };
    };
  };

  home.file = {
    ".config/nvim" = {
      recursive = true;
      source = /data/data/com.termux.nix/files/home/.local/src/reovim;
    };
  };

  programs.git = {
    enable = true;
    userName = "reo101";
    # userName = "Pavel Atanasov";
    userEmail = "pavel.atanasov2001@gmail.com";
  };

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 1800;
    enableSshSupport = true;
  };

  # Using nix-direnv
  # services.lorri = {
  #   enable = true;
  # };
}
