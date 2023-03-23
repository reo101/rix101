{ lib, fetchFromGitHub, rustPlatform, openssl, pkg-config, libxkbcommon }:

rustPlatform.buildRustPackage rec {
  pname = "vim-fmi-cli";
  version = "v0.1.14";

  src = fetchFromGitHub {
    owner = "AndrewRadev";
    repo = pname;
    rev = version;
    sha256 = "sha256-7Ek86uVa9fGaXwb8ZOzob2S27V+KYhogAFVLH4g20rU=";
  };

  cargoSha256 = "sha256-E2MSfypho15dYXdh2h5P/pwxxBJ8iQYVgEliUcrxugI=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [ ];

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
