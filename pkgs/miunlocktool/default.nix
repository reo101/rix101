{
  lib,
  android-tools,
  fetchFromGitHub,
  python3Packages,
}:

let
  migate = python3Packages.buildPythonPackage rec {
    pname = "migate";
    version = "1.1.6";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "offici5l";
      repo = "migate";
      rev = "v${version}";
      hash = "sha256-MIR8KWu1qq5Wt3WuOLnAviMQ/hbSBpfABzrfXcyReXU=";
    };

    build-system = [
      python3Packages.setuptools
      python3Packages.wheel
    ];

    dependencies = [
      python3Packages.qrcode
      python3Packages.requests
      python3Packages.rich
    ];

    pythonImportsCheck = [ "migate" ];

    meta = {
      description = "Simplified Xiaomi authentication gateway for Python projects";
      homepage = "https://github.com/offici5l/migate";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ reo101 ];
    };
  };
in
python3Packages.buildPythonApplication rec {
  pname = "miunlocktool";
  version = "1.7.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "offici5l";
    repo = "MiUnlockTool";
    rev = "v${version}";
    hash = "sha256-SBf5TFdasNTE2qfsqlF9SBCRbwNgcNnlTjNCpbK1Ips=";
  };

  sourceRoot = "source/MiUnlockTool";

  build-system = [
    python3Packages.setuptools
    python3Packages.wheel
  ];

  dependencies = [
    migate
  ];

  makeWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath [ android-tools ]}"
  ];

  pythonImportsCheck = [ "miunlock" ];

  meta = {
    description = "Retrieve Xiaomi encryptData(token) to unlock bootloader";
    homepage = "https://github.com/offici5l/MiUnlockTool";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ reo101 ];
    mainProgram = "miunlock";
    platforms = lib.platforms.unix;
  };
}
