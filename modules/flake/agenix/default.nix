{ lib, config, self, inputs, ... }:

{
  imports = [
    ../lib
    inputs.agenix-rekey.flakeModules.default
    ./secrets.nix
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
      identities = config.flake.secretsConfig.identities;
      identityFiles = builtins.readDir identities;

      # Get all .pub files
      pubFiles = lib.pipe identityFiles [
        (lib.filterAttrs
          (name: type:
            lib.hasSuffix ".pub" name))
      ];

      # Construct identity maps
      identityMappings = lib.pipe pubFiles [
        (lib.filterAttrs (name: _type:
          lib.hasSuffix ".pub" name))
        (lib.mapAttrsToList (name: _type: let
          baseName = lib.removeSuffix ".pub" name;
          pubFile = "${identities}/${baseName}.pub";
          ageFile = "${identities}/${baseName}.age";
          hasAgeFile = builtins.pathExists ageFile;
        in if hasAgeFile then {
          identity = ageFile;
          pubkey = lib.pipe pubFile [
            builtins.readFile
            (lib.removeSuffix "\n")
          ];
        } else {
          identity = pubFile;
          pubkey = null;
        }))
      ];
    in {
      masterIdentities = identityMappings;
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
      identities = lib.mkOption {
        type = types.path;
        default = "${inputs.self}/secrets/identities";
        defaultText = "\${inputs.self}/secrets/identities";
      };
      masterIdentities = lib.mkOption {
        type = agenix-rekey-options.masterIdentities.type;
      };
      extraEncryptionPubkeys = lib.mkOption {
        type = agenix-rekey-options.extraEncryptionPubkeys.type;
      };
    };
  };
}
