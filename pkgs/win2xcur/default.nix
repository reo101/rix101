{ lib, python3Packages, fetchPypi }:

python3Packages.buildPythonPackage rec {
  pname = "win2xcur";
  version = "0.1.2";

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-B8srOXQBUxK6dZ6GhDA5fYvxUBxHVcrSO/z+UWyF+qI=";
  };

  propagatedBuildInputs = with python3Packages; [
    numpy
    wand
  ];

  meta = with lib; {
    description = "win2xcur is a tool that converts cursors from Windows format (*.cur, *.ani) to Xcursor format. It also contains x2wincur which does the opposite.";
    homepage = "https://github.com/quantum5/win2xcur";
    maintainers = with maintainers; [ reo101 ];
  };
}
