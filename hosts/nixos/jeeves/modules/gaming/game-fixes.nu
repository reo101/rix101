def decode-save [format: string] {
  let raw = $in
  match $format {
    "json" => ($raw | from json)
    "xml" => ($raw | from xml)
    _ => (error make {msg: $"unsupported save format: ($format)"})
  }
}

def encode-save [format: string] {
  let value = $in
  match $format {
    "json" => ($value | to json)
    "xml" => ($value | to xml)
    _ => (error make {msg: $"unsupported save format: ($format)"})
  }
}

def main [width: int, height: int, data_root: path] {
  let fixes = [
    {
      name: "Slay the Spire 2"
      format: "json"
      files: {|root| glob $"($root)/steam/*/settings.save" }
      get: {|config| $config.window_size? | default {X: 0, Y: 0} }
      set: {|config, width, height|
        $config | upsert window_size {X: $width, Y: $height}
      }
    }
  ]

  for fix in $fixes {
    for settings in (do $fix.files $data_root) {
      let config = (open --raw $settings | decode-save $fix.format)
      let current = (do $fix.get $config)
      let updated = if $current.X == $width and $current.Y == $height {
        $config
      } else {
        do $fix.set $config $width $height
      }
      let tmp = $"($settings).tmp"
      $updated | encode-save $fix.format | save --force $tmp
      ^mv $tmp $settings
    }
  }
}
