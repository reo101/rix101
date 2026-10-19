{ lib, stdenv, uiua, ... }:

let
  # Reproduce Uiua's defaults without `binary_batteries`, which enables FFI.
  staticFeatures = [
    "binary"
    "batteries"
    "audio"
    "terminal_image"
    "lsp"
    "stand"
    "tls"
    "invoke"
    "trash"
    "native_sys"
    "raw_mode"
    "clipboard"
    "opt"
  ];
in
if stdenv.hostPlatform.isStatic or false then
  lib.infuse uiua {
    __output.cargoBuildNoDefaultFeatures.__assign = true;
    __output.buildFeatures.__assign = staticFeatures;
  }
else
  uiua
