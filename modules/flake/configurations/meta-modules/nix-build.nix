{ lib, config, ... }:

let
  inherit (lib) types;
in
{
  options = {
    nixBuildServer = lib.mkOption {
      description = "Remote Nix builder served by this host.";
      default = null;
      type = types.nullOr (types.submodule {
        options = {
          hostName = lib.mkOption {
            type = types.str;
            default = if config.deploy != null then config.deploy.hostname else config.hostname;
            description = "SSH hostname clients use for this builder.";
          };
          protocol = lib.mkOption {
            type = types.enum [ "ssh" "ssh-ng" ];
            default = "ssh-ng";
          };
          sshUser = lib.mkOption {
            type = types.str;
            default = "nixremote";
          };
          emulatedSystems = lib.mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Additional systems this builder can emulate.";
          };
          systems = lib.mkOption {
            type = types.listOf types.str;
            default = lib.unique (
              [ config.system ] ++ config.nixBuildServer.emulatedSystems
            );
          };
          maxJobs = lib.mkOption {
            type = types.ints.positive;
            default = 1;
          };
          speedFactor = lib.mkOption {
            type = types.ints.positive;
            default = 1;
          };
          supportedFeatures = lib.mkOption {
            type = types.listOf types.str;
            default = [ ];
          };
          mandatoryFeatures = lib.mkOption {
            type = types.listOf types.str;
            default = [ ];
          };
        };
      });
    };

    nixBuildClient = lib.mkOption {
      description = "Remote Nix builders this host should use.";
      default = { };
      type = types.submodule {
        options = {
          servers = lib.mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Hostnames from configurations.nixos whose nixBuildServer should be used.";
          };
          sshKey = lib.mkOption {
            type = types.path;
            default = /etc/ssh/ssh_host_ed25519_key;
            description = "Client-side private SSH key readable by root/Nix.";
          };
        };
      };
    };
  };
}
