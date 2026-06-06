{ lib, pkgs, ... }:

let
  cachixTokenRefreshNu = ./cachix-token-refresh.nu;
in
{
  type = "app";
  program = lib.getExe (pkgs.writeShellApplication {
    name = "cachix-token-refresh";
    runtimeInputs = [
      pkgs.cachix
      pkgs.coreutils
      pkgs.curl
      pkgs.nix
      pkgs.nushell
      pkgs.sqlite
    ];
    text = ''
      exec nu ${cachixTokenRefreshNu} "$@"
    '';
  });
}
