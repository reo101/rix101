{
  lib,
  pkgs,
  config,
  ...
}:

{
  home = {
    username = "reo101";
    homeDirectory = lib.mkForce "/home/${config.home.username}";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;

  # WSL only appends the Windows PATH for locally-launched sessions;
  # sshd-spawned shells get nothing. Static floor for non-interactive
  # ssh commands (zshenv); the full dynamic PATH is wired in zshrc below.
  home.sessionPath = [
    "/mnt/c/Windows/System32"
    "/mnt/c/Windows"
    "/mnt/c/Windows/System32/WindowsPowerShell/v1.0"
  ];

  # Dynamic Windows PATH: query it through interop, translate drive letters,
  # cache for 4h so shells don't pay a cmd.exe spawn every time.
  programs.zsh.initExtra = ''
    _winpath_cache="''${XDG_CACHE_HOME:-$HOME/.cache}/windows-path"
    if [[ ! -s "$_winpath_cache" ]] || [[ -n $(find "$_winpath_cache" -mmin +240 2>/dev/null) ]]; then
      mkdir -p "$_winpath_cache:h"
      /mnt/c/Windows/System32/cmd.exe /c "echo %PATH%" 2>/dev/null \
        | tr -d '\r' \
        | tr ';' '\n' \
        | sed -n -e 's|\\|/|g' -e 's|^\([A-Za-z]\):/|/mnt/\L\1/|p' \
        > "$_winpath_cache.tmp"
      if [[ -s "$_winpath_cache.tmp" ]]; then
        mv "$_winpath_cache.tmp" "$_winpath_cache"
      else
        rm -f "$_winpath_cache.tmp"
      fi
    fi
    if [[ -s "$_winpath_cache" ]]; then
      while IFS= read -r _d; do path+=("$_d"); done < "$_winpath_cache"
    fi
    unset _winpath_cache _d

    # Windows executables without the `.exe` suffix: retry unknown commands
    # with `.exe` appended before giving up (what stock WSL never does).
    command_not_found_handler() {
      local target="''${commands[$1.exe]}"
      if [[ -n "$target" ]]; then
        "$target" "''${@:2}"
        return $?
      fi
      print -u2 "zsh: command not found: $1"
      return 127
    }
  '';

  # Notepad++ lives in Program Files without touching PATH (Windows resolves
  # it via the App Paths registry, which WSL ignores)
  home.shellAliases."notepad++" = "/mnt/c/Program Files/Notepad++/notepad++.exe";

  rix101.shell = {
    enable = true;
    atuin = true;
    direnv = true;
    zoxide = true;
    shells = [
      "zsh"
      "nushell"
    ];
  };

  rix101.scm = {
    git.enable = true;
    jj.enable = true;
  };
}
