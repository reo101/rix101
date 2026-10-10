# Run with zsh -f; all files and caches live in a temporary directory.
setopt errexit

root=$(command mktemp -d)
trap 'command rm -rf -- "$root"' EXIT
export HOME="$root/home" XDG_CACHE_HOME="$root/cache" NIX_PROFILES=''
unset XDG_DATA_DIRS
command mkdir -p "$HOME" "$root/profile" "$root/custom" \
  "$root/version one/zsh/site-functions" "$root/version two/zsh/site-functions"

print -r -- $'#compdef environment-command\nprint -r -- baseline' > "$root/profile/_environment_complete"
print -r -- $'#compdef environment-command\nprint -r -- first' > "$root/version one/zsh/site-functions/_environment_complete"
print -r -- $'#compdef environment-command\nprint -r -- second' > "$root/version two/zsh/site-functions/_environment_complete"
print -r -- $'#compdef environment-only\nprint -r -- temporary' > "$root/version one/zsh/site-functions/_environment_only"
command touch -r "$root/version one/zsh/site-functions/_environment_complete" "$root/version two/zsh/site-functions/_environment_complete"

fpath=("$root/profile" $fpath)
source "${1:?completion initializer path required}"
[[ $_comps[environment-command] == _environment_complete ]]
[[ "$(_environment_complete)" == baseline ]]
# Load in the current shell as well, not solely in the command substitution.
_environment_complete > /dev/null
functions -c _rix101_completion_initialize _test_completion_initialize
initializations=0
_rix101_completion_initialize() {
  (( initializations += 1 ))
  _test_completion_initialize
}

# An unchanged prompt does no reindexing and preserves custom fpath entries.
fpath=("$root/custom" $fpath)
if _rix101_completion_synchronize; then exit 11; fi
(( initializations == 0 ))

export XDG_DATA_DIRS="$root/version one:$root/version one"
_rix101_completion_synchronize
(( initializations == 1 ))
[[ "$fpath[1]" == "$root/version one/zsh/site-functions" ]]
(( ${#_rix101_completion_environment_directories} == 1 ))
[[ "$(_environment_complete)" == first ]]
_environment_complete > /dev/null
[[ $_comps[environment-only] == _environment_only ]]
_environment_only > /dev/null

if _rix101_completion_synchronize; then exit 12; fi
(( initializations == 1 ))

# Replaced packages have equal file counts/mtimes, but different identities.
export XDG_DATA_DIRS="$root/version two"
_rix101_completion_synchronize
(( initializations == 2 ))
[[ "$(_environment_complete)" == second ]]
_environment_complete > /dev/null
[[ ! -v '_comps[environment-only]' ]]
[[ ! -v 'functions[_environment_only]' ]]
customDirectory="$root/custom"
profileDirectory="$root/profile"
firstDirectory="$root/version one/zsh/site-functions"
[[ ${fpath[(Ie)$customDirectory]} != 0 ]]
[[ ${fpath[(Ie)$profileDirectory]} != 0 ]]
[[ ${fpath[(Ie)$firstDirectory]} == 0 ]]

# Leaving restores the baseline implementation and removes environment state.
unset XDG_DATA_DIRS
_rix101_completion_synchronize
(( initializations == 3 ))
[[ "$(_environment_complete)" == baseline ]]
(( ${#_rix101_completion_environment_directories} == 0 ))
secondDirectory="$root/version two/zsh/site-functions"
[[ ${fpath[(Ie)$secondDirectory]} == 0 ]]

# Do not take ownership of profile paths or duplicate their symlink targets.
command mkdir -p "$root/profile-data/zsh"
command ln -s "$root/profile" "$root/profile-data/zsh/site-functions"
export XDG_DATA_DIRS="$root/profile-data"
_rix101_completion_synchronize
(( ${#_rix101_completion_environment_directories} == 0 ))

# Security audits still exclude insecure environment completion directories.
command mkdir -p "$root/insecure/zsh/site-functions"
print -r -- $'#compdef insecure-command\nprint -r -- insecure' > "$root/insecure/zsh/site-functions/_insecure_complete"
command chmod 777 "$root/insecure/zsh/site-functions"
export XDG_DATA_DIRS="$root/insecure"
_rix101_completion_synchronize
[[ ! -v '_comps[insecure-command]' ]]

# Versioned stdlib and vendor completion directories are discovered too.
command mkdir -p "$root/extra/zsh/$ZSH_VERSION/functions" "$root/extra/zsh/vendor-completions"
print -r -- $'#compdef version-command\nprint -r -- versioned' > "$root/extra/zsh/$ZSH_VERSION/functions/_version_complete"
print -r -- $'#compdef vendor-command\nprint -r -- vendor' > "$root/extra/zsh/vendor-completions/_vendor_complete"
export XDG_DATA_DIRS="$root/extra"
_rix101_completion_synchronize
[[ $_comps[version-command] == _version_complete ]]
[[ $_comps[vendor-command] == _vendor_complete ]]

# A failed initialization is distinguishable and cannot retry each prompt.
_rix101_completion_initialize() {
  (( initializations += 1 ))
  return 1
}
export XDG_DATA_DIRS="$root/failed"
if _rix101_completion_synchronize; then exit 13; else (( $? == 2 )); fi
failedInitializations=$initializations
if _rix101_completion_synchronize; then exit 14; else (( $? == 1 )); fi
(( initializations == failedInitializations ))

print -r -- 'completion environment checks passed'
