{ nixpkgs, stdenv, opentype-feature-freezer }:

let
  firacode = nixpkgs.pkgs.nerdfonts.override {
    fonts = [ "FiraCode" ];
  };
  fontSrc = "share/fonts/truetype/NerdFonts/Fira Code Regular Nerd Font Complete.ttf";
  fontDest = "Fira Code Regular Nerd Font Complete Patched.ttf";
in
stdenv.mkDerivation rec {
  name = "firacode-patched";
  version = "1.0";

  phases = [ "buildPhase" "installPhase" ];

  src = "${firacode}";

  buildInputs = [
    firacode
    opentype-feature-freezer
  ];

  features = 	nixpkgs.lib.strings.concatStringsSep "," [
    "liga"
    "cv02"
    "cv19"
    "cv25"
    "cv26"
    "cv28"
    "cv30"
    "cv32"
    "ss02"
    "ss03"
    "ss05"
    "ss07"
    "ss09"
    "zero"
  ];

  buildPhase = ''
    pyftfeatfreeze -f '${features}' -S -U " Patched" "${fontSrc}" "${fontDest}"
  '';

  installPhase = ''
    mkdir -p "$out/fonts/"
    cp "${fontDest}" "$out/fonts/"
  '';
}
