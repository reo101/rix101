{ lib, python3Packages, fetchFromGitHub }:

python3Packages.buildPythonPackage rec {
  pname = "hy-language-server";
  version = "0.0.7";

  src = fetchFromGitHub {
    owner = "rinx";
    repo = "hy-language-server";
    rev = "v${version}";
    hash = "sha256-x7HjR6S9pxeFDUuPkeDWhTSmpWR/woXN4H9Zzv9sWuo=";
  };

  format = "setuptools";

  propagatedBuildInputs = with python3Packages; [
    hy
    pygls
  ];

  doCheck = false;

  meta = with lib; {
    description = "hy language server using Jedhy";
    homepage = "https://github.com/rinx/hy-language-server";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    platforms = platforms.all;
  };
}
