# Run with: nu --no-config-file modules/home-manager/rix101-shell/tests/completion.nu
use std/assert

const completion_init = path self ../zsh/completion-init.zsh

let directory = (^mktemp -d | str trim)
try {
  let profile = ($directory | path join profile)
  let first_directory = ($directory | path join first share zsh site-functions)
  let second_directory = ($directory | path join second share zsh site-functions)
  mkdir $first_directory $second_directory
  "#compdef fixture-initial\n" | save ($first_directory | path join _fixture)
  "#compdef fixture-replacement\n" | save ($second_directory | path join _fixture)
  ^touch -t '197001010000.01' ($directory | path join first) ($directory | path join second)
  ^ln -s ($directory | path join first) $profile

  let run_completion = {|command|
    let result = (with-env {NIX_PROFILES: $profile, XDG_CACHE_HOME: $directory} {
      do {
        ^zsh -fc 'fpath=("$NIX_PROFILES/share/zsh/site-functions" "${fpath[@]}"); source "$1"; eval "$2"' -- $completion_init $command
      } | complete
    })
    assert equal $result.exit_code 0 $result.stderr
    $result.stdout | str trim
  }

  assert equal (do $run_completion 'print -r -- "${_comps[fixture-initial]}"') _fixture
  let marker = (glob ($directory | path join zsh '*.paths') | first)
  let initial_signature = (open --raw $marker)
  let initial_modified = (ls $marker | get modified.0)
  sleep 30ms
  assert equal (do $run_completion 'print -r -- "${_comps[fixture-initial]}"') _fixture
  assert equal (ls $marker | get modified.0) $initial_modified "cache hit should not rewrite the marker"

  rm $profile
  ^ln -s ($directory | path join second) $profile
  assert equal (do $run_completion 'print -r -- "${_comps[fixture-replacement]}"') _fixture
  assert ((open --raw $marker) != $initial_signature) "profile target changes must invalidate the cache"
  assert equal (do $run_completion 'print -r -- "${_comps[fixture-initial]-absent}"') absent
  rm $marker
  assert equal (do $run_completion 'print -r -- "${_comps[fixture-replacement]}"') _fixture
  print "completion cache checks passed"
} finally {
  rm --recursive $directory
}
