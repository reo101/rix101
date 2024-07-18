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

  cargoSha256 = "sha256-0OG0q6GTF7nvVWAwvJZ0lEri0rz42zN4xvT0VGp3n/I=";

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
