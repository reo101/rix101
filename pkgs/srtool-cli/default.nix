{ lib, stdenv, darwin, fetchFromGitHub, rustPlatform, openssl, pkg-config, libxkbcommon }:

rustPlatform.buildRustPackage rec {
  pname = "srtool-cli";
  version = "2e52c2c95d802d1a8a7da9b0f4c27a2b4ef5265a";

  src = fetchFromGitHub {
    owner = "chevdor";
    repo = pname;
    rev = "${version}";
    hash = "sha256-/vOQL5ru+Hyyydab1N7zKdqV+yeYc5CsqpWn58Ni7Wk=";
  };

  cargoSha256 = "sha256-pxWuIxp4UjyIMiy1WWU40IRVElX2LRuw5VmiSAdcbMU=";

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
    description = "This cli utility helps you harness the srtool docker image witout breaking a sweat.";
    homepage = "https://github.com/chevdor/srtool-cli";
    license = licenses.mit;
    maintainers = with maintainers; [ reo101 ];
  };
}
