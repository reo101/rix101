{ username }:
{
  # Get editor completions based on the config schema
  "$schema" = "https://starship.rs/config-schema.json";

  # Use custom format
  format = ''
    [╭───────┨](bold green)[${username}](bright-white)[@](bold yellow)$hostname[┠───────>](bold green)$status$cmd_duration$git_branch$git_status$git_state$git_commit
    [│](bold green)$time$jobs: $directory$package
    [╰─](bold green)''${custom.character_zsh}''${custom.character_nu}
  '';

  # ${custom.local}\
  # ${custom.local_root}\
  # ${custom.ssh}\
  # ${custom.ssh_root}\

  add_newline = true;

  custom.character_zsh = {
    shell = "/bin/sh";
    when = "[ $STARSHIP_SHELL = zsh ]";
    format = "[](bold green) ";
  };

  custom.character_nu = {
    shell = "/bin/sh";
    when = "[ $STARSHIP_SHELL = nu ]";
    format = "";
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
}
