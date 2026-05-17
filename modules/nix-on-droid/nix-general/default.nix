{ inputs, lib, ... }:

{ pkgs, ... }:

{
  nix = {
    package = lib.mkDefault pkgs.nix;

    registry = import ../../../nix/registry.nix { inherit lib inputs; };

    extraOptions = lib.mkDefault ''
      experimental-features = nix-command flakes

      keep-outputs = true
      keep-derivations = true
    '';
  };
}
