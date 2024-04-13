{ lib, fetchFromGitHub, rustPlatform, openssl, pkg-config, libxkbcommon }:

rustPlatform.buildRustPackage rec {
  pname = "envsub";
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "stephenc";
    repo = pname;
    rev = "refs/tags/${version}";
    hash = "sha256-DYfGH/TnDTaG5799upg4HDNFiMYpkE64s2DNXJ+1NnE=";
  };

  cargoSha256 = "sha256-1b0nhfbk7g2XiplOeVB25VQV2E3Z7B9tqANYvhOO6AQ=";

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
