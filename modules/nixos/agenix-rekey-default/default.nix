{ inputs, lib, pkgs, config, options, ... }:
{
  config = {
    # NOTE: `(r)agenix` and `agenix-rekey` modules are imported by `../../../modules/flake/configurations.nix`
    age.rekey = {
      masterIdentities = lib.mkDefault [ "${inputs.self}/secrets/privkey.age" ];
      storageMode      = lib.mkDefault "local";
      localStorageDir  = lib.mkDefault "${inputs.self}/secrets/rekeyed/${config.networking.hostName}";
    };
  };
}
