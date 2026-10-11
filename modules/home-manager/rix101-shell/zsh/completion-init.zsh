autoload -Uz compinit

_rix101_completion_initialize() {
  local directory="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
  local dump="$directory/zcompdump-$HOST-$ZSH_VERSION"
  local target signature
  local -a targets
  for target in ${(z)NIX_PROFILES} "${fpath[@]}"; do
    targets+=("$target" "${target:A}")
  done
  signature="${(pj:\n:)targets}"

  # Nix store mtimes are normalized. Compare resolved profile/fpath identities,
  # not timestamps, and regenerate even when the file count is unchanged.
  # Mutable completions at an unchanged path require deleting the marker.
  if [[ -s "$dump" && -r "$dump.paths" ]] \
      && [[ "$(<"$dump.paths")" == "$signature" ]]; then
    compinit -C -d "$dump"
  else
    command mkdir -p -- "$directory"
    command rm -f -- "$dump" "$dump.zwc"
    # Exclude insecure directories without blocking startup or prompt refresh.
    compinit -i -d "$dump" || return
    print -r -- "$signature" > "$dump.paths.$$"
    command mv -f -- "$dump.paths.$$" "$dump.paths"
  fi
}

typeset -ga _rix101_completion_environment_directories

# Return 0 after refresh, 1 when unchanged, and 2 when initialization fails.
_rix101_completion_synchronize() {
  local dataDirectories="${XDG_DATA_DIRS-}"
  [[ -v _rix101_completion_data_signature && "$dataDirectories" == "$_rix101_completion_data_signature" ]] && return 1
  local directory dataDirectory file
  local -aU directories

  # Remove only the directories this integration previously added. Preserve
  # profile paths and additions from other shell integrations.
  fpath=("${(@)fpath:|_rix101_completion_environment_directories}")
  local -a existingDirectories=("${(@)fpath:A}")
  for dataDirectory in "${(@s.:.)dataDirectories}"; do
    [[ -n "$dataDirectory" ]] || continue
    for directory in "$dataDirectory"/zsh/{site-functions,$ZSH_VERSION/functions,vendor-completions}(N-/); do
      directory=${directory:A}
      (( ${existingDirectories[(Ie)$directory]} )) || directories+=("$directory")
    done
  done

  # An autoloaded function retains its old body after fpath changes. Unload
  # both departing and overriding environment functions before reindexing.
  for directory in "${_rix101_completion_environment_directories[@]}" "${directories[@]}"; do
    for file in "$directory"/_*(N-.); do
      (( $+functions[${file:t}] )) && unfunction -- "${file:t}"
    done
  done
  fpath=("${directories[@]}" "${fpath[@]}")
  _rix101_completion_environment_directories=("${directories[@]}")
  # compinit adds definitions but does not remove obsolete command mappings.
  if (( $+_comps )); then
    _comps=() _services=() _patcomps=() _postpatcomps=() _compautos=()
  fi
  # Remember failed attempts too, so an unchanged prompt cannot retry forever.
  typeset -g _rix101_completion_data_signature="$dataDirectories"
  _rix101_completion_initialize || return 2
}

_rix101_completion_synchronize || _rix101_completion_initialize
