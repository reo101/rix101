{ lib, config, self, inputs, ... }:

{
  imports = [
    inputs.agenix-rekey.flakeModule
  ];

  perSystem = {
    agenix-rekey = {
      nodes = self.nixosConfigurations // self.darwinConfigurations;
    };
  };

  flake = {
    # The identities that are used to rekey all agenix secrets:
    # - classic agenix secrets, specific to one host
    # - (r)age-encrypted nix files, specific to one host
    # - (r)age-encrypted nix files for repository-wide secrets
    config.secretsConfig = let
      identities = "${inputs.self}/secrets/identities";
    in {
      masterIdentities = [
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
      extraEncryptionPubkeys = [
        # TODO: what exactly does this do
        # "${identities}/age-backup.pub"
      ];
    };

    options.secretsConfig = let
      # HACK: extract types from `agenix-rekey` module definition
      agenix-rekey-options = (inputs.agenix-rekey.nixosModules.agenix-rekey {
        inherit lib;
        config = null;
        pkgs = null;
      }).options.age.rekey;
    in {
      masterIdentities = lib.mkOption {
        type = agenix-rekey-options.masterIdentities.type;
      };
      extraEncryptionPubkeys = lib.mkOption {
        type = agenix-rekey-options.extraEncryptionPubkeys.type;
      };
    };
  };
}
