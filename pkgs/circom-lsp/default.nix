{ lib, fetchFromGitHub, rustPlatform, ... }:

rustPlatform.buildRustPackage rec {
  pname = "circom-lsp";
  version = "0.1.3";

  src = "${fetchFromGitHub {
    owner = "rubydusa";
    repo = pname;
    rev = "refs/tags/v${version}";
    hash = "sha256-Y71qmeDUh6MwSlFrSnG+Nr/un5szTUo27+J/HphGr7M=";
  }}/server";

  cargoHash = "sha256-R/DgNJi2vx8opqh5THlRQA1b9FIl+fkXYruyx7f9HKc=";

  doCheck = false;

  meta = with lib; {
    description = "A Language Server Protocol Implementation for Circom";
    homepage = "https://github.com/rubydusa/circom-lsp";
    license = licenses.isc;
    maintainers = with maintainers; [ reo101 ];
  };
}
