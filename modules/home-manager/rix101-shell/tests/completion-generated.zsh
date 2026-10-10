source "${1:?generated zshrc path required}"
setopt errexit

(( $precmd_functions[(Ie)_direnv_hook] > 0 ))
(( $precmd_functions[(Ie)_direnv_hook] < $precmd_functions[(Ie)_rix101_completion_refresh] ))
(( $+functions[_carapace_completer] ))
originalPath=$PATH
originalHandler=$_comps[git]
originalBinding=$(bindkey -M viins '^R')
originalDataDirectories=${XDG_DATA_DIRS-}

for version in first second; do
  directory="$HOME/completion $version/zsh/site-functions"
  command mkdir -p "$directory"
  print -r -- "#compdef environment-command"$'\n'"print -r -- $version" > "$directory/_environment_complete"
done

export XDG_DATA_DIRS="$HOME/completion first:$originalDataDirectories"
_rix101_completion_refresh
[[ $_comps[environment-command] == _environment_complete ]]
[[ "$(_environment_complete)" == first ]]
_environment_complete > /dev/null

export XDG_DATA_DIRS="$HOME/completion second:$originalDataDirectories"
_rix101_completion_refresh
[[ "$(_environment_complete)" == second ]]
_environment_complete > /dev/null
[[ $_comps[git] == $originalHandler ]]
[[ $PATH == $originalPath ]]
[[ "$(bindkey -M viins '^R')" == "$originalBinding" ]]

export XDG_DATA_DIRS=$originalDataDirectories
_rix101_completion_refresh
[[ ! -v '_comps[environment-command]' ]]
[[ $_comps[git] == $originalHandler ]]
[[ "$(bindkey -M viins '^R')" == "$originalBinding" ]]

# A failed compinit still restores Carapace, without a per-prompt retry loop.
initializations=0
_rix101_completion_initialize() {
  (( initializations += 1 ))
  return 1
}
export XDG_DATA_DIRS="$HOME/completion first:$originalDataDirectories"
_rix101_completion_refresh
[[ $_comps[git] == $originalHandler ]]
[[ $PATH == $originalPath ]]
[[ "$(bindkey -M viins '^R')" == "$originalBinding" ]]
_rix101_completion_refresh
(( initializations == 1 ))

print -r -- 'generated completion/direnv/Carapace checks passed'
