$env.config = {
  show_banner: false

  edit_mode: vi
  history: {
    ignore_space_prefixed: true
  }
  cursor_shape: {
    vi_insert: line
    vi_normal: block
  }
}

def "nu-complete git generate gitignore" [] {
  if (stor open | schema | get tables | columns | where $in == nu_complete_gitignore | is-empty) {
    # Fetch first: the table is only populated after a successful HTTP fetch,
    # so a failed fetch can be retried on the next completion.
    let templates = (
      http get "https://www.toptal.com/developers/gitignore/dropdown/templates.json"
        | each { |obj| {
            value: $obj.id
            description: $obj.text
          } }
    )
    if ($templates | is-empty) {
      error make {msg: "gitignore template service returned an empty list; retry completion later"}
    }
    stor create -t nu_complete_gitignore -c {value:str description:str}
    $templates | stor insert -t nu_complete_gitignore
  }
  stor open | query db "select * from nu_complete_gitignore"
}

def "git generate gitignore" [
  --force
  --path: string = ".gitignore"
  ...langs: string@"nu-complete git generate gitignore"
] {
  if ($langs | is-empty) {
    error make {msg: "no gitignore template specified; name one or more languages"}
  }
  # A bare filename yields an empty dirname; its parent is the current directory.
  let parent = if ($path | path dirname | is-empty) { '.' } else { $path | path dirname }
  if ($parent | path type) != 'dir' {
    error make {msg: $"destination directory \"($parent)\" does not exist or is not a directory"}
  }
  if ($path | path exists) {
    if ($path | path expand | path type) == 'dir' {
      error make {msg: $"destination \"($path)\" is a directory"}
    }
    if not $force {
      error make {msg: $"\"($path)\" already exists. add --force to override it."}
    }
  }

  # Fetch before writing, then publish a unique sibling on the same filesystem.
  let content = (http get $"https://www.toptal.com/developers/gitignore/api/($langs | str join ',')")
  let download = ($parent | path join $".gitignore.(random uuid).part")
  try {
    $content | save $download
    if ($path | path expand | path type) == 'dir' {
      error make {msg: $"destination \"($path)\" is a directory"}
    }
    let mode = if $force { '--force' } else { '--no-clobber' }
    # Nu's mv cannot reject directory targets; use the pinned GNU executable.
    let publication = (do {
      ^$gitignore_move_program --no-target-directory --no-copy $mode -- $download $path
    } | complete)
    if $publication.exit_code != 0 {
      error make {msg: $"gitignore replacement failed: ($publication.stderr | str trim)"}
    }
    if ($download | path exists) {
      error make {msg: $"\"($path)\" appeared during download; refusing to overwrite it"}
    }
  } finally {
    if ($download | path exists) { rm --permanent $download }
  }
}

def copy []: string -> nothing {
  print -n $"(ansi osc)52;c;($in | encode base64)(ansi st)"
}

$env.config.keybindings = ($env.config.keybindings | append [
  {
    name: copy_commandline
    modifier: alt
    keycode: char_c
    mode: [ vi_normal vi_insert ]
    event: {
      send: executehostcommand
      cmd: 'commandline | copy'
    }
  }
  {
    name: copy_formatted_commandline
    modifier: alt_shift
    keycode: char_c
    mode: [ vi_normal vi_insert ]
    event: {
      send: executehostcommand
      cmd: 'commandline | nu-highlight | $"```ansi\n($in)\n```" | copy'
    }
  }
])
