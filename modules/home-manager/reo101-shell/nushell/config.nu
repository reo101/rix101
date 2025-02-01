$env.config = {
  show_banner: false

  edit_mode: vi
  cursor_shape: {
    vi_insert: line
    vi_normal: block
  }
}

def "nu-complete git generate gitignore" [] {
  if (stor open | schema | get tables | columns | where $in == nu_complete_gitignore | is-empty) {
    stor create -t nu_complete_gitignore -c {value:str description:str}
    http get "https://www.toptal.com/developers/gitignore/dropdown/templates.json"
      | each { |obj| {
          value: $obj.id
          description: $obj.text
        } }
      | stor insert -t nu_complete_gitignore
  }
  stor open | query db "select * from nu_complete_gitignore"
}

def "git generate gitignore" [
  --force
  --path: string = ".gitignore"
  ...langs: string@"nu-complete git generate gitignore"
] {
  if ($path | path exists) {
    if $force {
      rm -f $path
    } else {
      raise error $"\"($path)\" already exists. add --force to override it."
    }
  }

  http get $"https://www.toptal.com/developers/gitignore/api/($langs | str join ',')" | save $path
}

def copy []: string -> nothing {
    print -n $"(ansi osc)52;c;($in | encode base64)(ansi st)"
}

$env.config.keybindings = [
  {
    name: copy_commandline
    modifier: alt
    keycode: char_c
    mode: [ vi_normal vi_insert ]
    event: {
      send: executehostcommand
      cmd: 'commandline | nu-highlight | $"` ``ansi\n($in)\n` ``" | copy'
    }
  }
]
