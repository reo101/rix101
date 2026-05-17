{ inputs, lib, ... }:

{ pkgs, ... }:

{
  nix = {
    package = lib.mkDefault pkgs.nixVersions.latest;

    registry = import ../../../nix/registry.nix { inherit lib inputs; };

    settings = {
      experimental-features = lib.mkDefault [
        "nix-command"
        "flakes"
      ];

      auto-optimise-store = lib.mkDefault true;
      keep-outputs = lib.mkDefault true;
      keep-derivations = lib.mkDefault true;
    };
  };
}
