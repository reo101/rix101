{ lib, stdenv, darwin, fetchFromGitHub, rustPlatform, openssl, pkg-config, libxkbcommon }:

rustPlatform.buildRustPackage rec {
  pname = "vim-fmi-cli";
  version = "v0.1.16";

  src = fetchFromGitHub {
    owner = "AndrewRadev";
    repo = pname;
    rev = version;
    sha256 = "sha256-pirsTb2GUxIjxTg0oJgfb7QzvgGTsBa2HBdcogsEB1M=";
  };

  cargoSha256 = "sha256-5Tr8tnWsQtYYNqPBSA/nT6ggvxjUvE3/AwkeJwUeMcY=";

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
