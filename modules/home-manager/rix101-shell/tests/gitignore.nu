# Run from the repository root with: nu --no-config-file modules/home-manager/rix101-shell/tests/gitignore.nu
# HTTP is mocked; all writes are confined to a temporary directory.
use std/assert

def "http get" [url: string] {
  if ($env.MOCK_HTTP_FAIL? | default false) {
    error make {msg: "mock network failure"}
  }
  if ($url =~ 'templates.json') {
    $env.MOCK_TEMPLATES_JSON? | default [{id: 'rust', text: 'Rust'} {id: 'go', text: 'Go'}]
  } else {
    if ($env.MOCK_CREATE_DESTINATION? | default '' | is-not-empty) {
      'concurrent file' | save $env.MOCK_CREATE_DESTINATION
    }
    '# mock gitignore'
  }
}

const gitignore_move_program = 'mv'
source ../nushell/config.nu

let original_directory = $env.PWD
let test_directory = (mktemp -d -t rix101-gitignore-test.XXXXXXXX | str trim)
try {
  cd $test_directory

  $env.MOCK_TEMPLATES_JSON = []
  assert (try { nu-complete git generate gitignore; false } catch { true })
  hide-env MOCK_TEMPLATES_JSON
  $env.MOCK_HTTP_FAIL = true
  assert (try { nu-complete git generate gitignore; false } catch { true })
  $env.MOCK_HTTP_FAIL = false
  assert equal (nu-complete git generate gitignore | length) 2
  $env.MOCK_HTTP_FAIL = true
  assert equal (nu-complete git generate gitignore | length) 2
  $env.MOCK_HTTP_FAIL = false

  'original' | save .gitignore
  assert (try { git generate gitignore --path .gitignore rust; false } catch { true })
  assert equal (open --raw .gitignore) 'original'
  assert (try { git generate gitignore --path other.gitignore; false } catch { true })
  assert (not ('other.gitignore' | path exists))
  assert (try { git generate gitignore --path missing-dir/.gitignore rust; false } catch { true })

  mkdir destination-directory
  ^ln -s destination-directory destination-link
  assert (try { git generate gitignore --force --path destination-directory rust; false } catch { true })
  assert (try { git generate gitignore --force --path destination-link rust; false } catch { true })

  $env.MOCK_HTTP_FAIL = true
  assert (try { git generate gitignore --force --path .gitignore rust; false } catch { true })
  assert equal (open --raw .gitignore) 'original'
  $env.MOCK_HTTP_FAIL = false

  'unrelated staging file' | save .gitignore.part
  git generate gitignore --force --path .gitignore rust go
  assert equal (open --raw .gitignore) '# mock gitignore'
  assert equal (open --raw .gitignore.part) 'unrelated staging file'

  $env.MOCK_CREATE_DESTINATION = 'concurrent.gitignore'
  assert (try { git generate gitignore --path concurrent.gitignore rust; false } catch { true })
  assert equal (open --raw concurrent.gitignore) 'concurrent file'
  hide-env MOCK_CREATE_DESTINATION

  ^ln -s absent-file dangling.gitignore
  assert (try { git generate gitignore --path dangling.gitignore rust; false } catch { true })
  assert equal (^readlink dangling.gitignore | str trim) 'absent-file'
  git generate gitignore --force --path dangling.gitignore rust
  assert equal (open --raw dangling.gitignore) '# mock gitignore'

  # Insert a directory after validation, immediately before GNU mv executes.
  let original_path = $env.PATH
  let real_move = (which --all mv | where type == external | first | get path)
  mkdir publication-program
  '#!/bin/sh\nmkdir "$GITIGNORE_TEST_DESTINATION"\nexec "$GITIGNORE_TEST_MOVE" "$@"\n'
    | str replace --all '\n' (char newline)
    | save publication-program/mv
  assert equal (do { ^chmod 700 publication-program/mv } | complete).exit_code 0
  try {
    $env.PATH = ($original_path | prepend ($env.PWD | path join publication-program))
    $env.GITIGNORE_TEST_MOVE = $real_move
    for force in [false true] {
      let destination = $"directory-race-($force)"
      $env.GITIGNORE_TEST_DESTINATION = $destination
      assert (try { git generate gitignore --force=$force --path $destination rust; false } catch { true })
      assert equal ($destination | path type) 'dir'
      assert (ls $destination | is-empty)
    }
  } finally {
    $env.PATH = $original_path
    hide-env GITIGNORE_TEST_MOVE GITIGNORE_TEST_DESTINATION
  }

  mkdir readonly
  'protected' | save readonly/.gitignore
  assert equal (do { ^chmod 500 readonly } | complete).exit_code 0
  try {
    assert (try { git generate gitignore --force --path readonly/.gitignore rust; false } catch { true })
    assert equal (open --raw readonly/.gitignore) 'protected'
    assert (glob ($env.PWD | path join readonly/.gitignore.*.part) | is-empty)
  } finally {
    # Drain the external process before the outer finally removes the fixture.
    assert equal (do { ^chmod 700 readonly } | complete).exit_code 0
  }
  assert (glob ($env.PWD | path join .gitignore.*.part) | is-empty)
} finally {
  cd $original_directory
  rm --recursive --permanent $test_directory
}
print 'gitignore regression checks passed'
