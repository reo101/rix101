{ lib, darwin, ... }:

darwin.apple_sdk.stdenv.mkDerivation {
  name = "get_menu_bar_height";
  version = "0.0.1";

  src = lib.cleanSource ./src;

  buildPhase = ''
    clang -framework cocoa get_menu_bar_height.m -o get_menu_bar_height
  '';

  installPhase = ''
    mkdir -p $out/bin
    mv get_menu_bar_height $out/bin/get_menu_bar_height
  '';

  meta.mainProgram = "get_menu_bar_height";
}
