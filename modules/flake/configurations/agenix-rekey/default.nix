{ host-type }:

{
  inputs,
  lib,
  config,
  options,
  meta,
  ...
}:

{
  config = {
    # NOTE: `(r)agenix` and `agenix-rekey` modules are imported by `../default.nix`
    age.rekey = {
      # NOTE: defined in `meta.nix`
      # hostPubkey       = null;
      masterIdentities = lib.mkDefault inputs.self.secretsConfig.masterIdentities;
      extraEncryptionPubkeys = lib.mkDefault inputs.self.secretsConfig.extraEncryptionPubkeys;
      storageMode = lib.mkDefault "local";
      localStorageDir = lib.mkDefault
        {
          nixos = "${inputs.self}/secrets/rekeyed/nixos/${meta.hostname}";
          darwin = "${inputs.self}/secrets/rekeyed/darwin/${meta.hostname}";
          homeManager = "${inputs.self}/secrets/rekeyed/home-manager/${meta.hostname}/${config.home.username}";
        }
        .${host-type} or (throw "agenix-module-for: unsupported host-type '${host-type}'");
    };
  };
}
