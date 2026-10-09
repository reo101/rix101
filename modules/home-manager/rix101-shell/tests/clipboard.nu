# Capture OSC 52 output in subprocesses, never send it to the real terminal.
use std/assert
const gitignore_move_program = 'mv'
source ../nushell/config.nu

let source_file = ($env.FILE_PWD | path join ../nushell/config.nu | path expand)
let command = 'cargo test -- "quoted argument"'
for binding in ($env.config.keybindings | where name in [copy_commandline copy_formatted_commandline]) {
  let script = $"const gitignore_move_program = 'mv'; def commandline [] { ($command | to nuon) }; source ($source_file | to nuon); ($binding.event.cmd)"
  let result = (do { ^nu --no-config-file -c $script } | complete)
  assert equal $result.exit_code 0
  let content = if $binding.name == copy_commandline {
    $command
  } else {
    let highlighted = ($command | nu-highlight)
    $"```ansi\n($highlighted)\n```"
  }
  assert equal $result.stdout $"(ansi osc)52;c;($content | encode base64)(ansi st)"
}
print 'clipboard regression checks passed'
