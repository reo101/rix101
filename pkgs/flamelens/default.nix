{ lib, fetchFromGitHub, rustPlatform }:

rustPlatform.buildRustPackage rec {
  pname = "flamelens";
  version = "v0.2.0";

  src = fetchFromGitHub {
    owner = "YS-L";
    repo = pname;
    rev = version;
    hash = "sha256-v8SBd5KkGok4hmAwSKmnKgxq3Ghipho7W7UYHW/2EMg=";
  };

  cargoHash = "sha256-Rm4pRmTqxLCPMVeFCeb0Gg/AV1olMsG0UKB75i5iyB8=";

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
