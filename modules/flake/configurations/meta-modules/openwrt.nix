# OpenWrt tofu-managed host metadata, deploy-rs style.
#
# Each `hosts/openwrt/*/meta.nix` sets `openwrt = { ... }` to declare that the
# router/AP is managed by the `openwrt-tofu` app (see `apps/openwrt-tofu` and
# `apps/openwrt-tofu`). Fields mirror `renderSystemUci` from its `hosts.nix`.
{
  lib,
  config,
  ...
}:

let
  inherit (lib)
    mkOption
    types
    ;
in
{
  options.openwrt = mkOption {
    description = ''
      OpenTofu/LuCI-RPC management settings for this OpenWrt host.
      `null` (default) means the host is only built as an image, not
      managed via tofu.
    '';
    type = types.nullOr (types.submodule (
      { ... }:
      {
        options = {
          remote = mkOption {
            description = "LuCI JSON-RPC base URL the provider talks to";
            type = types.str;
          };
          user = mkOption {
            description = "LuCI admin account";
            type = types.str;
            default = "root";
          };
          secret = mkOption {
            description = ''
              Secret file (relative to `secrets/master/`) holding the LuCI
              admin password, age-encrypted.
            '';
            type = types.str;
          };
          system = mkOption {
            description = "Declared /etc/config/system content";
            type = types.submodule {
              options = {
                hostname = mkOption {
                  type = types.str;
                };
                timezone = mkOption {
                  type = types.str;
                };
                zonename = mkOption {
                  type = types.str;
                };
                ntp = mkOption {
                  description = "NTP servers; `null` omits the block (APs)";
                  type = types.nullOr (types.listOf types.str);
                  default = null;
                };
                logProto = mkOption {
                  type = types.str;
                  default = "udp";
                };
                conloglevel = mkOption {
                  type = types.str;
                  default = "8";
                };
                cronloglevel = mkOption {
                  type = types.str;
                  default = "5";
                };
                ttylogin = mkOption {
                  type = types.str;
                  default = "0";
                };
                logSize = mkOption {
                  type = types.str;
                  default = "64";
                };
              };
            };
          };
        };
      }
    ));
    default = null;
  };
}
