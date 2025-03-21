{ lib, config, self, inputs, ... }:

{
  imports = [
    inputs.agenix-rekey.flakeModules.default
  ];

  perSystem = {
    agenix-rekey = {
      nixosConfigurations = self.nixosConfigurations;
      # TODO:
      # darwinConfigurations = self.darwinConfigurations;
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
        "${identities}/age-yubikey-1-identity-20250322.pub"
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
      inherit (lib) types;
      # HACK: extract types from `agenix-rekey` module definition
      agenix-rekey-options = (lib.evalModules {
        modules = [
          inputs.agenix-rekey.nixosModules.default
          "${inputs.nixpkgs.outPath}/nixos/modules/misc/assertions.nix"
        ];
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
