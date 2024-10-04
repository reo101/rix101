# TODO: AppleSelectedInputSourcesChangedNotification
{ lib, darwin, writeShellApplication, sketchybar, babashka, clj-kondo, ... }:

let
  plugin-dir = ./plugins;
  util-dir = ./utils;
  get-menu-bar-height = darwin.apple_sdk.stdenv.mkDerivation {
    name = "get_menu_bar_height";
    version = "0.0.1";
    src = lib.cleanSource ./get_menu_bar_height;
    buildInputs = with darwin.apple_sdk.frameworks; [
      Cocoa
    ];
    buildPhase = ''
      clang -framework cocoa get_menu_bar_height.m -o get_menu_bar_height
    '';
    installPhase = ''
      mkdir -p $out/bin
      mv get_menu_bar_height $out/bin/get_menu_bar_height
    '';
    meta.mainProgram = "get_menu_bar_height";
  };
  sketchybar-config-script = ./config.clj;
in
writeShellApplication {
  name = "sketchybar-config";
  text = ''
    export PLUGIN_DIR="${plugin-dir}"
    export UTIL_DIR="${util-dir}"

    exec ${lib.getExe babashka} \
      --file ${sketchybar-config-script} \
      --plugin-dir ${plugin-dir} \
      --util-dir ${util-dir} \
      --get-menu-bar-height ${lib.getExe get-menu-bar-height}
  '';
  runtimeInputs = [
    sketchybar
  ];
  checkPhase = ''
    ${lib.getExe clj-kondo} \
      --config '{:linters {:namespace-name-mismatch {:level :off}}}' \
      --lint ${sketchybar-config-script}
  '';
}
