{ lib, fetchFromGitHub, darwin, ... }:

# TODO: fix clang issue (works with native `/usr/bin/clang`)
#
# > Undefined symbols for architecture arm64:
# >   "_SLSWindowManagementBridgeSetDelegate", referenced from:
# >       _main in main.o
# > ld: symbol(s) not found for architecture arm64

darwin.apple_sdk.stdenv.mkDerivation rec {
  pname = "JankyBorders";
  version = "dev";

  src = fetchFromGitHub {
    owner = "FelixKratz";
    repo = "JankyBorders";
    rev = "6bc201813bc163c6f5a20d5fa744f7b0d1f31773";
    sha256 = "sha256-b4+aJkP1yqz8x5EUDDVQmqrmLus+Y69RViAeaLvfGXE=";
  };

  buildInputs = with darwin.apple_sdk.frameworks; [
    AppKit
    SkyLight
    darwin.apple_sdk.Libsystem
  ];
}
