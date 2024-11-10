{ lib, config, self, inputs, ... }:

{
  config.lib = {
    rageImportEncrypted =
      assert lib.assertMsg (builtins ? extraBuiltins.rageImportEncrypted)
      "The extra builtin `rageImportEncrypted` is not available, so secrets cannot be decrypted. Did you forget to use `nix-enraged`? (or manually set up `nix-plugins` and `extra-builtins-file`)";
      builtins.extraBuiltins.rageImportEncrypted
       (lib.map
         ({ identity, pubkey }: identity)
         config.flake.secretsConfig.masterIdentities);
  };
}
