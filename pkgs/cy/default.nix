{ lib
, pkg-config
, xorg
, fetchFromGitHub
, buildGoModule
, ...
}:

buildGoModule rec {
  pname = "cy";
  version = "1.3.1";

  src = fetchFromGitHub {
    owner = "cfoust";
    repo = "${pname}";
    rev = "v${version}";
    hash = "sha256-i5suNLh1Dy8sWKBasO1rnVRzDetEF77XXRonRk1RzB4=";
  };

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    xorg.libX11
  ];

  vendorHash = null;

  doCheck = false;
}
