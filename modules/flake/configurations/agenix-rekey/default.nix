{ inputs, lib, pkgs, config, options, ... }:
{
  config = {
    # NOTE: `(r)agenix` and `agenix-rekey` modules are imported by `../default.nix`
    age.rekey = {
      # NOTE: defined in `meta.nix`
      # hostPubkey       = null;
      masterIdentities = let
        identities = "${inputs.self}/secrets/identities";
      in lib.mkDefault [
        "${identities}/age-yubikey-1-identity-9306892a.pub"
        "${identities}/age-yubikey-2-identity-bb8456bc.pub"
        {
          identity = "${identities}/age-backup-private.age";
          pubkey = lib.pipe "${identities}/age-backup.pub" [
            builtins.readFile
            (lib.removeSuffix "\n")
          ];
        }
      ];
      storageMode = lib.mkDefault "local";
      localStorageDir = lib.mkDefault "${inputs.self}/secrets/rekeyed/${config.networking.hostName}";
    };
  };
}
