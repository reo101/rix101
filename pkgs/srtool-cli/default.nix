{ lib, stdenv, fetchFromGitHub, rustPlatform, ... }:

rustPlatform.buildRustPackage rec {
  pname = "srtool-cli";
  version = "0.13.2";

  src = fetchFromGitHub {
    owner = "chevdor";
    repo = pname;
    tag = "v${version}";
    hash = "sha256-uLQ+y2vP/Odv/ICqypHUvqnuHPiAfmJtWpG5kLgVWi8=";
  };

  cargoHash = "sha256-O70wFsx7CWDtvRIRYvZybXpFP71L9C6TxUprnEQtASA=";

  doCheck = false;

  meta = with lib; {
    description = "This cli utility helps you harness the srtool docker image witout breaking a sweat.";
    homepage = "https://github.com/chevdor/srtool-cli";
    license = licenses.mit;
    maintainers = with maintainers; [ reo101 ];
  };
}
