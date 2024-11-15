{ lib, config, self, inputs, ... }:

{
  config.lib = {
    # TODO: move into `default-generators.nix` or similar
    rageImportEncrypted = masterIdentities: hostPlatform:
      assert lib.assertMsg (builtins ? extraBuiltins.rageImportEncrypted)
      "The extra builtin `rageImportEncrypted` is not available, so secrets cannot be decrypted. Did you forget to use `nix-enraged`? (or manually set up `nix-plugins` and `extra-builtins-file`)";
      builtins.extraBuiltins.rageImportEncrypted
        (lib.pipe config.flake.secretsConfig.masterIdentities [
          (lib.filter
            ({ identity, pubkey }:
              # NOTE: cannot not use `YubiKey`s on `nix-on-droid`
              # TODO: better detection of `nix-on-droid`
              if hostPlatform.isLinux && hostPlatform.isAarch64
              # TODO: better detection of `yubikey`
              then !lib.hasInfix "yubikey" identity
              else true))
          (lib.map
            ({ identity, pubkey }:
              identity))
        ]);
  };
}
