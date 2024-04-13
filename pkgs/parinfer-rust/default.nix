{ lib, fetchFromGitHub, rustPlatform, openssl, pkg-config, libxkbcommon }:

rustPlatform.buildRustPackage rec {
  pname = "parinfer-rust";
  version = "3c769707ad3b18d530f696fe42a9d495139149ab";

  src = fetchFromGitHub {
    owner = "eraserhd";
    repo = pname;
    rev = version;
    hash = "sha256-EVFuCZo6lYXEOWQzTW7BEfB5PIbO4YA4dCMo7N4oWrM=";
  };

  cargoSha256 = "sha256-spKA4GDoEIg7CBICiEcHsxmxkt8yC5jLjXSFMAUUJGs=";

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
