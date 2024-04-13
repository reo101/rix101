{ lib, stdenv, darwin, fetchFromGitHub, rustPlatform, openssl, pkg-config, libxkbcommon }:

rustPlatform.buildRustPackage rec {
  pname = "pest-ide-tools";
  version = "8de1ee91765b0257c2ccfbf48f6b5bd39158bc2c";

  src = fetchFromGitHub {
    owner = "pest-parser";
    repo = pname;
    rev = "${version}";
    hash = "sha256-PSYbmFEYGGDPvHl9AjDSoedRx1Y7A5HT1gqPcGeVkv4=";
  };

  cargoSha256 = "sha256-wvMAo+XgnSfUb36nJWSAL3TAcnWzPOpaCdvJnpcyol0=";

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
    description = "IDE tools for writing pest grammars, using the Language Server Protocol for Visual Studio Code, Vim and other editors";
    homepage = "https://github.com/pest-ide-tools/pest-parser";
    license = licenses.mit;
    maintainers = with maintainers; [ reo101 ];
  };
}
