# Generic OpenTofu runner, agnostic over the OpenWrt host being managed:
#
#   nix run .#openwrt-tofu -- .#asus_tuf-ax4200 plan
#   nix run .#openwrt-tofu -- .#deco_m4r_v2-1 apply
#
# Per-host data (remote/user/secret/terraform JSON) is assembled from the
# hosts' `meta.nix` files at build time into one JSON, baked into this app
# (see `apps/openwrt-tofu/hosts.nix`); the host is selected here at runtime.
{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  hostsFile = import ./hosts.nix {
    inherit (inputs) terranix;
    inherit lib pkgs;
  };
  provider = pkgs.custom.terraform-provider-openwrt;
  version = provider.version or "0.2.0";
  # NOTE: exact layout OpenTofu expects for `provider_installation`
  mirrorDir = pkgs.runCommand "openwrt-provider-mirror" { } ''
    dir="$out/registry.terraform.io/foxboron/openwrt/${version}/linux_amd64"
    mkdir -p "$dir"
    ln -s ${lib.getExe provider} \
      "$dir/terraform-provider-openwrt_v${version}"
  '';
  # default decryption identity (YubiKey); override via OPENWRT_IDENTITY
  identityFile = toString ../../secrets/identities/01-age-yubikey-1-identity-20250322.pub;
in
{
  type = "app";
  program = lib.getExe (pkgs.writeShellApplication {
    name = "openwrt-tofu";
    runtimeInputs = [
      pkgs.age-plugin-yubikey
      pkgs.coreutils
      pkgs.nushell
      pkgs.opentofu
      pkgs.rage
    ];
    text = ''
      host="$1"
      if [ -z "$host" ]; then
        echo "usage: nix run .#openwrt-tofu -- .#<host> [plan|apply|destroy]" >&2
        exit 1
      fi
      host="''${host#.\#}"
      export OPENWRT_CONFIG="${hostsFile}"
      export OPENWRT_HOST="$host"
      export OPENWRT_PROVIDER_MIRROR="${mirrorDir}"
      export OPENWRT_IDENTITY="${identityFile}"
      exec ${lib.getExe pkgs.nushell} ${./openwrt-tofu.nu} "''${2:-plan}"
    '';
  });
}
