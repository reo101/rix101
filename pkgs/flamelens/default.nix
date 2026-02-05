{ lib, fetchFromGitHub, rustPlatform }:

rustPlatform.buildRustPackage rec {
  pname = "flamelens";
  version = "v0.4.0";

  src = fetchFromGitHub {
    owner = "YS-L";
    repo = pname;
    rev = version;
    hash = "sha256-b7lRMyeX/aL1ziSaLBUxChrwXeKNhcCShjGY6ANYqhY=";
  };

  cargoHash = "sha256-QcEN83Cd92i0Ll+8uWSLREKk5i0STwhAKTCx48BiI6A=";

  nativeBuildInputs = [
  ];

  buildInputs = [
  ];

  doCheck = false;

  meta = with lib; {
    description = "Flamegraph viewer in the terminal ";
    homepage = "https://github.com/YS-L/flamelens";
    license = licenses.mit;
    maintainers = with maintainers; [ reo101 ];
  };
}
