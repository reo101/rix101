{ lib, callPackage, pkgsi686Linux, ... }:

let
  native = callPackage ./package.nix { };
in
lib.infuse native {
  __output.passthru.i686.__assign = pkgsi686Linux.callPackage ./package.nix { };
}
