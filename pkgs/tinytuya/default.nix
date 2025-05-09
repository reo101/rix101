{ lib, python3Packages, fetchFromGitHub }:

python3Packages.buildPythonPackage rec {
  pname = "tinytuya";
  version = "1.13.2";

  src = fetchFromGitHub {
    owner = "jasonacox";
    repo = "tinytuya";
    rev = "v${version}";
    hash = "sha256-/aoSrOkvG2hHh25s1iT+oK8+M6FNc/SvWtDYNNllDU0=";
  };

  pyproject = true;

  nativeBuildInputs = with python3Packages; [
    setuptools
  ];

  propagatedBuildInputs = with python3Packages; [
    requests
    colorama
    cryptography
  ];

  doCheck = false;

  meta = with lib; {
    description = "Python module to interface with Tuya WiFi smart devices";
    homepage = "https://github.com/jasonacox/tinytuya";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    platforms = platforms.all;
  };
}
