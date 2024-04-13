{ lib, stdenv, darwin, fetchFromGitHub, rustPlatform, openssl, pkg-config, libxkbcommon }:

rustPlatform.buildRustPackage rec {
  pname = "vim-fmi-cli";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "AndrewRadev";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-RAlvDiNvDVRNtex0aD8WESc4R/mAr7FjWtgzHWa4ZSI=";
  };

  cargoLock = {
    lockFile = builtins.fetchurl {
      url = "https://raw.githubusercontent.com/AndrewRadev/vim-fmi-cli/v${version}/Cargo.lock";
      sha256 = "sha256-PfJ8N5aFffMxaWt0UrsUZjpTbR+b5UZfFxftZ72+fl4=";
    };
  };

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [ ] ++ lib.optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [
    SystemConfiguration
    CoreServices
  ]);

  PKG_CONFIG_PATH = "${openssl.dev}/lib/pkgconfig";
  LD_LIBRARY_PATH = lib.makeLibraryPath buildInputs;

  doCheck = false;

  meta = with lib; {
    description = "The command-line tool for https://www.vim-fmi.bg";
    homepage = "https://github.com/AndrewRadev/vim-fmi-cli";
    license = licenses.mit;
    maintainers = with maintainers; [ reo101 ];
  };
}
