{ lib, python3Packages, fetchFromGitHub, fetchPypi }:

python3Packages.buildPythonPackage rec {
  pname = "soularr";
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "mrusse";
    repo = pname;
    rev = "9248e59044e05ab8083b3065df8ddcab03232332";
    hash = "sha256-pTQX8GWTlKTASu1sT1fobKHB70gUHTRGqvrlgYQt1B8=";
  };

  preBuild = ''
    cat > setup.py << PYTHON
from setuptools import setup

with open("requirements.txt") as f:
    install_requires = f.read().splitlines()

setup(
  name='${pname}',
  version='${version}',
  author='mrusse',
  description='${meta.description}',
  install_requires=install_requires,
  scripts=[
    '${pname}.py',
  ],
)
PYTHON
  '';

  postInstall = ''
    mv -v $out/bin/${pname}.py $out/bin/${pname}
  '';

  dependencies = with python3Packages; [
    music-tag
    pyarr
    (python3Packages.buildPythonPackage rec {
      pname = "slskd-api";
      version = "0.1.5";

      src = fetchPypi {
        inherit pname version;
        hash = "sha256-LmWP7bnK5IVid255qS2NGOmyKzGpUl3xsO5vi5uJI88=";
      };

      build-system = with python3Packages; [
        pip
      ];
    })
  ];

  meta = with lib; {
    description = "A Python script that connects Lidarr with Soulseek!";
    homepage = "https://github.com/mrusse/soularr";
    maintainers = with maintainers; [ reo101 ];
  };
}
