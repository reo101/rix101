{ config, lib, ... }: let
  inherit (lib) types;
in {
  options = {
    enable = lib.mkOption {
      description = "Whether to enable this host's configuration";
      type = types.bool;
      default = true;
    };
    hostname = lib.mkOption {
      description = "Hostname of the machine";
      type = types.str;
      # NOTE: set as a config-side default outside
      # default = host;
    };
    system = lib.mkOption {
      description = "The `system` of the host";
      type = types.str;
    };
    pubkey = lib.mkOption {
      description = "The host SSH key, used for encrypting agenix secrets";
      type = types.nullOr types.str;
      default = null;
    };
    deploy = lib.mkOption {
      type = types.nullOr (types.submodule (deploySubmodule: {
        options = {
          hostname = lib.mkOption {
            description = ''
              This is the hostname by which you'll refer to this machine using reploy-rs
            '';
            type = types.str;
            default = config.hostname;
          };
          sshUser = lib.mkOption {
            description = ''
              This is the user that deploy-rs will use when connecting.
              This will default to your own username if not specified anywhere
            '';
            type = types.nullOr types.str;
            default = null;
          };
          user = lib.mkOption {
            description = ''
              This is the user that the profile will be deployed to (will use sudo if not the same as above).
              If `sshUser` is specified, this will be the default (though it will _not_ default to your own username)
            '';
            type = types.str;
            default = "root";
          };
          sudo = lib.mkOption {
            description = ''
              Which sudo command to use. Must accept at least two arguments:
              the user name to execute commands as and the rest is the command to execute
            '';
            type = types.str;
            default = "sudo -u";
          };
          sshOpts = lib.mkOption {
            description = ''
              This is an optional list of arguments that will be passed to SSH.
            '';
            type = types.listOf types.str;
            default = [];
          };
          fastConnection = lib.mkOption {
            description = ''
              Fast connection to the node. If this is true, copy the whole closure instead of letting the node substitute.
            '';
            type = types.bool;
            default = false;
          };
          autoRollback = lib.mkOption {
            description = ''
              If the previous profile should be re-activated if activation fails.
            '';
            type = types.bool;
            default = true;
          };
          magicRollback = lib.mkOption {
            description = ''
              See the earlier section about Magic Rollback for more information.
            '';
            type = types.bool;
            default = true;
          };
          tempPath = lib.mkOption {
            description = ''
              The path which deploy-rs will use for temporary files, this is currently only used by `magicRollback` to create an inotify watcher in for confirmations
              (if `magicRollback` is in use, this _must_ be writable by `user`)
            '';
            type = types.str;
            default = "/tmp";
          };
          remoteBuild = lib.mkOption {
            description = ''
              Build the derivation on the target system
              Will also fetch all external dependencies from the target system's substituters.
            '';
            type = types.bool;
            default = false;
          };
        };
      }));
      default = null;
    };
  };
}
