{ lib, schema }:
{
  # Keep editor completions aligned with the configured package.
  "$schema" = "file://${schema}";

  # Use custom format
  format = ''
    [╭───────┨](bold green)$username$hostname[┠───────>](bold green)$status$cmd_duration$vcs
    [│](bold green)$time$jobs: $directory$package$nix_shell
    [╰─](bold green)$character
  '';

  add_newline = true;

  character = {
    success_symbol = "[](bold green)";
    error_symbol = "[](bold red)";
    vimcmd_symbol = "[](bold green)";
  };

  vcs = {
    # Git-first discovery would hide jj in colocated repositories.
    order = [
      "jj"
      "git"
    ];
    jj_modules = "$jj_bookmark$jj_change$jj_status";
    git_modules = "$git_branch$git_status$git_state$git_commit";
  };
  jj_bookmark.truncation_length = 15;
  jj_change.change_hash_length = 6;
  git_branch.truncation_length = 15;
  git_commit.commit_hash_length = 6;

  nix_shell.format = "[nix:$state( \\($name\\))](bold blue) ";

  status = {
    style = "bg:blue fg:red";
    symbol = "🔴";
    format = "[\\[$symbol $common_meaning$signal_name$maybe_int\\]]($style) ";
    map_symbol = true;
    disabled = false;
  };

  time = {
    disabled = false;
    format = "🕙[$time]($style) ";
    time_format = "%T";
  };

  cmd_duration = {
    min_time = 2000;
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

  directory.substitutions =
    let
      components = {
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
    in
    # Upstream regex substitutions replace the first matching component.
    lib.mapAttrsToList (component: symbol: {
      from = "(^|/)${lib.escapeRegex component}(/|$)";
      to = "\${1}${symbol}\${2}";
      regex = true;
    }) components;

  # Language Environments
  package = {
    style = "bold fg:#5E5E5E";
  };

  # Custom
  jobs = {
    format = "[ $symbol$number ]($style)";
    style = "bg:#587744 fg:bright-white";
    symbol = "⚙";
  };

}
