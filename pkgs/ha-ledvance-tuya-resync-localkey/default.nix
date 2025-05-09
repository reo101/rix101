{ lib, python3Packages, fetchFromGitHub }:

python3Packages.buildPythonApplication rec {
  pname = "ha-ledvance-tuya-resync-localkey";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "omBratteng";
    repo = pname;
    rev = "2cc079267a0b4628fca3f87144cae3906a655934";
    hash = "sha256-8aSwFZlvo0Y5r7Gyi0nz7EtnjeSN5tsafS4ejicIMAk=";
  };

  pyproject = true;

  nativeBuildInputs = with python3Packages; [
    setuptools
  ];

  propagatedBuildInputs = with python3Packages; [
    pycryptodome
    requests
  ];

  dontCheckRuntimeDeps = true;

  postInstall = ''
    mkdir -p $out/bin
    install -m755 $src/main.py $out/bin/ledvance-resync
  '';

  meta = {
    description = "pyscript for homeassistant to resync local keys from private tuya api";
    homepage = "https://github.com/omBratteng/ha-ledvance-tuya-resync-localkey";
    mainProgram = "ledvance-resync";
    license = lib.licenses.unfree; # License not specified in repo
    maintainers = with lib.maintainers; [ reo101 ];
    platforms = lib.platforms.unix;
  };
}
