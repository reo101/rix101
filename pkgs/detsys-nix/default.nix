{ inputs }:
{ pkgs, ... }:

inputs.nix.packages.${pkgs.stdenv.hostPlatform.system}.nix
