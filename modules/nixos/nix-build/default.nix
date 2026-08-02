{
  inputs,
  lib,
  meta,
  pkgs,
  config,
  ...
}:

let
  nixos = inputs.self.configurations.nixos or { };
  metas = lib.mapAttrs (_: configuration: configuration.meta) nixos;

  client = meta.nixBuildClient;
  server = meta.nixBuildServer;

  serverMetas = map (
    host:
    metas.${host} or (builtins.throw "Unknown nixBuildClient.servers host '${host}'")
  ) client.servers;

  clientsForMe = lib.filterAttrs (
    _: clientMeta:
    builtins.elem meta.hostname clientMeta.nixBuildClient.servers
  ) metas;

  machineFor = serverMeta:
    let
      s = serverMeta.nixBuildServer;
    in
    {
      inherit (s)
        hostName
        protocol
        sshUser
        systems
        maxJobs
        speedFactor
        supportedFeatures
        mandatoryFeatures
        ;
      sshKey = toString client.sshKey;
    };
in
{
  config = lib.mkMerge [
    (lib.mkIf (client.servers != [ ]) {
      programs.ssh.knownHosts = lib.listToAttrs (map (serverMeta: {
        name = "nix-builder-${serverMeta.hostname}";
        value = {
          hostNames = [ serverMeta.nixBuildServer.hostName ];
          publicKey = serverMeta.pubkey;
        };
      }) serverMetas);

      nix = {
        distributedBuilds = true;
        buildMachines = map machineFor serverMetas;
        settings.builders-use-substitutes = lib.mkDefault true;
      };
    })

    (lib.mkIf (server != null) {
      boot.binfmt.emulatedSystems = server.emulatedSystems;
      nix.settings.extra-platforms = config.boot.binfmt.emulatedSystems;

      users.users.${server.sshUser} = {
        isNormalUser = true;
        shell = pkgs.bashInteractive;
        openssh.authorizedKeys.keys = lib.mapAttrsToList (_: clientMeta: clientMeta.pubkey) clientsForMe;
      };

      nix.settings.trusted-users = [ server.sshUser ];
    })
  ];
}
