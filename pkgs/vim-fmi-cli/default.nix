{ lib, stdenv, fetchFromGitHub, rustPlatform, ... }:

rustPlatform.buildRustPackage rec {
  pname = "vim-fmi-cli";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "AndrewRadev";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-RAlvDiNvDVRNtex0aD8WESc4R/mAr7FjWtgzHWa4ZSI=";
  };

  cargoLock.lockFile = "${src}/Cargo.lock";

  doCheck = false;

  meta = with lib; {
    description = "The command-line tool for https://www.vim-fmi.bg";
    homepage = "https://github.com/AndrewRadev/vim-fmi-cli";
    license = licenses.mit;
    maintainers = with maintainers; [ reo101 ];
  };
}
