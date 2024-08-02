{ lib
, stdenv
, darwin
# Fetchers
, fetchFromGitHub
# Build inputs
, cmake
, pkg-config
, iconv
, pcre
, readline
, glib
, zlib
, ...
}:

stdenv.mkDerivation rec {
  pname = "sdcv";
  version = "0.5.5";

  src = fetchFromGitHub {
    owner = "Dushistov";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-EyvljVXhOsdxIYOGTzD+T16nvW7/RNx3DuQ2OdhjXJ4=";
  };

  nativeBuildInputs = [
    pkg-config
    cmake
    iconv
  ];

  buildInputs = [
    pcre
    readline
    glib
    zlib
  ];

  cmakeFlags = [
    # BUG: <https://github.com/Dushistov/sdcv/blob/49c8094b53b7dd90efeabeaf276752a650a0f931/CMakeLists.txt#L58> does not exit
    "-DENABLE_NLS=OFF"
  ];

  meta = with lib; {
    description = "Console version of StarDict";
    homepage = "https://github.com/Dushistov/sdcv";
    license = licenses.gpl2;
    # maintainers = with maintainers; [ reo101 ];
  };
}
