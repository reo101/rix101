{ inputs, meta, lib, pkgs, config, options, ... }:
{
  config = {
    # NOTE: `(r)agenix` and `agenix-rekey` modules are imported by `../default.nix`
    age.rekey = {
      # NOTE: defined in `meta.nix`
      # hostPubkey       = null;
      masterIdentities = lib.mkDefault inputs.self.secretsConfig.masterIdentities;
      extraEncryptionPubkeys = lib.mkDefault inputs.self.secretsConfig.extraEncryptionPubkeys;
      storageMode = lib.mkDefault "local";
      localStorageDir = lib.mkDefault "${inputs.self}/secrets/rekeyed/${meta.hostname}";
    };
  };
}
