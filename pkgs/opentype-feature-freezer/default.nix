{ lib, python3 }:

python3.pkgs.buildPythonApplication rec {
  pname = "opentype-feature-freezer";
  version = "1.32.2";

  src = python3.pkgs.fetchPypi {
    inherit pname version;
    sha256 = "cdc93320bfee4e2f1455476f2b5618d82f47c0d86532f1b69673666adcc2b573";
  };

  propagatedBuildInputs = with python3.pkgs; [ fonttools ];

  meta = with lib; {
    # ...
  };
}

# nixpkgs.pypyPackages.opentype-feature-freezer
