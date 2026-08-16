# openwrt-tofu: run tofu plan|apply|destroy against an OpenWrt host via the
# terraform-provider-openwrt (LuCI-RPC) provider.
#
# Host selection and data come from the nix-side wrapper (apps/openwrt-tofu):
#   OPENWRT_HOST     host name to manage
#   OPENWRT_CONFIG   path to the hosts JSON (pkgs.openwrt-tf output)
#   OPENWRT_PROVIDER_MIRROR  filesystem-mirror dir for the provider
#   OPENWRT_IDENTITY optional age identity override
# The LuCI admin password is decrypted here (age; YubiKey by default) and
# handed to tofu as OPENWRT_PASSWORD.
def main [cmd: string = "plan"] {
  if $cmd not-in [plan apply destroy] {
    error make { msg: $"unknown command '($cmd)'; use plan|apply|destroy" }
  }

  let hosts = (open $env.OPENWRT_CONFIG)
  let host = ($env.OPENWRT_HOST? | default "")
  let cfg = if $host == "" { null } else { $hosts | get -o $host }
  if $cfg == null {
    error make {
      msg: $"unknown OpenWrt host '($host)'; known: ($hosts | columns | str join ', ')"
    }
  }

  let state_dir = (
    $env.XDG_STATE_HOME?
    | default (($env.HOME? | default '') | path join ".local" "state")
    | path join "rix101"
  )
  mkdir $state_dir

  let dir = (mktemp -d)
  try {
    if not ($cfg.secret | path exists) {
      error make { msg: $"missing secret: ($cfg.secret)" }
    }

    # provider from a Nix-built filesystem mirror (no registry/network)
    $"
    provider_installation {
      filesystem_mirror {
        path = \"($env.OPENWRT_PROVIDER_MIRROR)\"
      }
    }
    " | save -f ($dir | path join "tfrc")

    $cfg.content | save -f ($dir | path join "main.tf.json")

    let identity = ($env.OPENWRT_IDENTITY? | default "")
    let password = if ($identity | is-empty) {
      (^rage -d $cfg.secret | str trim)
    } else {
      (^rage -d -i $identity $cfg.secret | str trim)
    }
    $env.OPENWRT_PASSWORD = $password

    $env.TF_CLI_CONFIG_FILE = ($dir | path join "tfrc")
    tofu $"-chdir=($dir)" init -input=false
    tofu $"-chdir=($dir)" $cmd -state ($state_dir | path join $"openwrt-($host).tfstate")
  } finally {
    rm -rf $dir
  }
}
