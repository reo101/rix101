# Live OpenWrt management metadata. Named UCI sections exposed by host modules
# are reconciled through NixOps4; the older tofu fields remain during migration.
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
      Live management settings for this OpenWrt host. `null` means the host is
      only built as an image.
    '';
    type = types.nullOr (types.submodule (
      { ... }:
      {
        options = {
          host = mkOption {
            description = "SSH hostname or address for NixOps4";
            type = types.str;
          };
          port = mkOption {
            description = "SSH port for NixOps4";
            type = types.port;
            default = 22;
          };
          dryRun = mkOption {
            description = "Report NixOps4 changes without writing them";
            type = types.bool;
            default = true;
          };
          secretFile = mkOption {
            description = "Runtime-encrypted generic router configuration, relative to the repository";
            type = types.nullOr types.str;
            default = null;
          };
          rollbackTimeout = mkOption {
            description = "Seconds before an unconfirmed live apply rolls back";
            type = types.ints.positive;
            default = 60;
          };
          pruneOrphans = mkOption {
            description = "Delete sections previously stamped by NixOps4 whose declaration was removed";
            type = types.bool;
            default = false;
          };
          reloadServices = mkOption {
            description = "Services restarted after a confirmed apply";
            type = types.listOf types.str;
            default = [ ];
          };
          # Legacy tofu fields — kept for APs not yet migrated to NixOps4
          remote = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          secret = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          configFiles = mkOption {
            type = types.attrsOf types.str;
            default = { };
          };
          system = mkOption {
            type = types.nullOr (
              types.submodule {
                options = {
                  hostname = mkOption { type = types.str; };
                  timezone = mkOption { type = types.str; };
                  zonename = mkOption { type = types.str; };
                  ntp = mkOption { type = types.nullOr (types.listOf types.str); default = null; };
                  logProto = mkOption { type = types.str; default = "udp"; };
                  conloglevel = mkOption { type = types.str; default = "8"; };
                  cronloglevel = mkOption { type = types.str; default = "5"; };
                  ttylogin = mkOption { type = types.str; default = "0"; };
                  logSize = mkOption { type = types.str; default = "64"; };
                };
              }
            );
            default = null;
          };
        };
      }
    ));
    default = null;
  };
}
