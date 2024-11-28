{ lib, config, self, inputs, ... }:

{
  config.lib = let
    hasRageImportEncrypted = (builtins ? extraBuiltins.rageImportEncrypted);
    missingMsg = "The extra builtin `rageImportEncrypted` is not available, so secrets cannot be decrypted. Did you forget to use `nix-enraged`? (or manually set up `nix-plugins` and `extra-builtins-file`)";
    hintMsg = hasDefault: if hasDefault then
      "Using provided default value"
    else
      "No default value provided, did you forget to supply one?";
    # assertion = lib.assertMsg hasRageImportEncrypted missingMsg;
    importOrDefaultFrom = args: identities: file:
      if hasRageImportEncrypted then
        builtins.extraBuiltins.rageImportEncrypted identities file
      else if args ? default then
        lib.trace (missingMsg + "\n" + hintMsg true)
          args.default
      else
        builtins.throw (missingMsg + "\n" + hintMsg false);

    rageImportEncryptedRaw = args@{
      identities ? config.flake.secretsConfig.masterIdentities,
      filter ? lib.const true,
      # NOTE: cannot use `null` as default, as that might be a valid real default
      # default,
      ...
    }: importOrDefaultFrom args
      (lib.pipe identities [
        (lib.filter filter)
        (lib.map
          ({ identity, pubkey }:
            identity))
      ]);

    rageImportEncryptedByHostPlatform = hostPlatform:
      rageImportEncryptedRaw {
        filter = { identity, pubkey }:
          # NOTE: cannot not use `YubiKey`s on `nix-on-droid`
          # TODO: better detection of `nix-on-droid`
          if hostPlatform.isLinux && hostPlatform.isAarch64 then
            # TODO: better detection of `yubikey`
            !lib.hasInfix "yubikey" identity
          else
            true;
      };

    rageImportEncryptedBySystem = system:
      rageImportEncryptedRaw {
        filter = { identity, pubkey }:
          # NOTE: cannot not use `YubiKey`s on `nix-on-droid`
          # TODO: better detection of `nix-on-droid`
          if system == "aarch64-linux" then
            # TODO: better detection of `yubikey`
            !lib.hasInfix "yubikey" identity
          else
            true;
      };

    # NOTE: all identities, no filter,
    #       relies on `AGENIX_REKEY_PRIMARY_IDENTITY`
    rageImportEncrypted = rageImportEncryptedRaw {};
  in {
    inherit
      rageImportEncryptedRaw
      rageImportEncryptedByHostPlatform
      rageImportEncryptedBySystem
      rageImportEncrypted
      ;
  };
}
