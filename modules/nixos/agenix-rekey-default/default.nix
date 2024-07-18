{ inputs, outputs, lib, pkgs, config, options, ... }:
let
  # NOTE: synced with <https://github.com/oddlama/agenix-rekey/blob/c071067f7d972552f5170cf8665643ed0ec19a6d/modules/agenix-rekey.nix#L38>
  dummyPubkey = "age1qyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqs3290gq";
in {
  # TODO: cleaner deep check
  config = lib.mkIf (lib.all lib.id [(builtins.hasAttr "age" options) (builtins.hasAttr "rekey" options.age)]) {
    age.rekey = lib.mkIf (config.age.rekey.hostPubkey != dummyPubkey) {
      masterIdentities = [ "${inputs.self}/secrets/privkey.age" ];
      storageMode = "local";
      localStorageDir = "${inputs.self}/secrets/rekeyed/${config.networking.hostName}";
    };
  };
}
