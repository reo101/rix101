{ lib, stdenv, darwin, fetchFromGitHub, rustPlatform, openssl, pkg-config, libxkbcommon }:

rustPlatform.buildRustPackage rec {
  pname = "vim-fmi-cli";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "AndrewRadev";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-RAlvDiNvDVRNtex0aD8WESc4R/mAr7FjWtgzHWa4ZSI=";
  };

  cargoSha256 = "sha256-XaBVtnUsifLKZtfxFNr7o/1A70FQRItyo00KbV4W6Pk=";

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
