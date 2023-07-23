{ lib, fetchFromGitHub, rustPlatform, openssl, pkg-config, libxkbcommon }:

rustPlatform.buildRustPackage rec {
  pname = "circom-lsp";
  version = "0.1.3";

  src = "${fetchFromGitHub {
    owner = "rubydusa";
    repo = pname;
    rev = "refs/tags/v${version}";
    sha256 = "sha256-Y71qmeDUh6MwSlFrSnG+Nr/un5szTUo27+J/HphGr7M=";
  }}/server";

  cargoSha256 = "sha256-Lq8SpzkUqYgayQTApNngOlhceAQAPG9Rwg1pmGvyxnM=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [ ];

  PKG_CONFIG_PATH = "${openssl.dev}/lib/pkgconfig";
  LD_LIBRARY_PATH = lib.makeLibraryPath buildInputs;

  doCheck = false;

  meta = with lib; {
    description = "A Language Server Protocol Implementation for Circom";
    homepage = "https://github.com/rubydusa/circom-lsp";
    license = licenses.isc;
    maintainers = with maintainers; [ reo101 ];
  };
}
