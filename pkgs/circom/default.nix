{ lib, fetchFromGitHub, rustPlatform, openssl, pkg-config, libxkbcommon }:

rustPlatform.buildRustPackage rec {
  pname = "circom";
  version = "2.1.6";

  src = fetchFromGitHub {
    owner = "iden3";
    repo = pname;
    rev = "refs/tags/v${version}";
    hash = "sha256-2YusBWAYDrTvFHYIjKpALphhmtsec7jjKHb1sc9lt3Q=";
  };

  cargoHash = "sha256-ovPHMFYbzEhHbmtVhTjxlrUYF7fH0fhoznnd0F2cKUQ=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [ ];

  PKG_CONFIG_PATH = "${openssl.dev}/lib/pkgconfig";
  LD_LIBRARY_PATH = lib.makeLibraryPath buildInputs;

  doCheck = false;

  meta = with lib; {
    description = "zkSnark circuit compiler";
    homepage = "https://github.com/iden3/circom";
    license = licenses.isc;
    maintainers = with maintainers; [ reo101 ];
  };
}
