autoload -Uz compinit

_rix101_completion_directory="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
_rix101_completion_dump="$_rix101_completion_directory/zcompdump-$HOST-$ZSH_VERSION"
_rix101_completion_targets=()
for _rix101_completion_path in ${(z)NIX_PROFILES} "${fpath[@]}"; do
  _rix101_completion_targets+=("$_rix101_completion_path" "${_rix101_completion_path:A}")
done
_rix101_completion_signature="${(pj:\n:)_rix101_completion_targets}"

# Nix store mtimes are normalized. Compare resolved profile/fpath identities,
# not timestamps, and force regeneration even when the file count is unchanged.
# Mutable completions at an unchanged path require deleting the dump or marker.
if [[ -s "$_rix101_completion_dump" && -r "$_rix101_completion_dump.paths" ]] \
    && [[ "$(<"$_rix101_completion_dump.paths")" == "$_rix101_completion_signature" ]]; then
  compinit -C -d "$_rix101_completion_dump"
else
  command mkdir -p -- "$_rix101_completion_directory"
  command rm -f -- "$_rix101_completion_dump" "$_rix101_completion_dump.zwc"
  # Audit permissions and exclude insecure directories without blocking startup.
  if compinit -i -d "$_rix101_completion_dump"; then
    print -r -- "$_rix101_completion_signature" > "$_rix101_completion_dump.paths.$$"
    command mv -f -- "$_rix101_completion_dump.paths.$$" "$_rix101_completion_dump.paths"
  fi
fi
unset _rix101_completion_directory _rix101_completion_dump _rix101_completion_targets
unset _rix101_completion_path _rix101_completion_signature
