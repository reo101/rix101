{ lib, stdenv, fetchFromGitHub, rustPlatform }:

rustPlatform.buildRustPackage rec {
  pname = "pest-ide-tools";
  version = "0.3.11";

  src = fetchFromGitHub {
    owner = "pest-parser";
    repo = pname;
    tag = "v${version}";
    hash = "sha256-12/FndzUbUlgcYcwMT1OfamSKgy2q+CvtGyx5YY4IFQ=";
  };

  cargoHash = "sha256-wLdVIAwrnAk8IRp4RhO3XgfYtNw2S07uAHB1mokZ2lk=";

  doCheck = false;

  meta = with lib; {
    description = "IDE tools for writing pest grammars, using the Language Server Protocol for Visual Studio Code, Vim and other editors";
    homepage = "https://github.com/pest-parser/pest-ide-tools";
    license = licenses.mit;
    maintainers = with maintainers; [ reo101 ];
  };
}
