{ lib, fetchFromGitHub, rustPlatform, openssl, pkg-config, libxkbcommon }:

rustPlatform.buildRustPackage rec {
  pname = "parinfer-rust";
  version = "4d4f4c6c0d3b44c8443f3102bfadfb67dfb385f7";

  src = fetchFromGitHub {
    owner = "eraserhd";
    repo = pname;
    rev = version;
    sha256 = lib.fakeSha256;
  };

  cargoSha256 = lib.fakeSha256;

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [ ];

  PKG_CONFIG_PATH = "${openssl.dev}/lib/pkgconfig";
  LD_LIBRARY_PATH = lib.makeLibraryPath buildInputs;

  doCheck = false;

  meta = with lib; {
    description = "A Rust port of parinfer.";
    homepage = "https://github.com/eraserhd/parinfer-rust";
    license = licenses.isc;
    maintainers = with maintainers; [ reo101 ];
  };
}
