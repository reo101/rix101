{ lib, fetchFromGitHub, darwin, ... }:

darwin.apple_sdk.stdenv.mkDerivation rec {
  pname = "JankyBorders";
  version = "dev";

  src = fetchFromGitHub {
    owner = "FelixKratz";
    repo = pname;
    rev = "e2af0248fa40ead3f17f1d16c6288b8ddfd9f505";
    hash = "sha256-rYA6b6d3c4pJVUIV77z/JMcgKbZ+4qZdxkI21LwZcG4=";
  };

  buildInputs = with darwin.apple_sdk.frameworks; [
    AppKit
    SkyLight
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp ./bin/borders $out/bin/
  '';
}
