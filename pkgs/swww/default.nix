{ lib, fetchFromGitHub, rustPlatform, pkg-config, libxkbcommon }:

rustPlatform.buildRustPackage rec {
  pname = "swww";
  version = "v0.7.1";

  src = fetchFromGitHub {
    owner = "Horus645";
    repo = pname;
    rev = version;
    sha256 = "sha256-Z90Zwjqcu0hbtJwKPUNV996mtdgX//ZWWm+Dya/JV9A=";
  };

  cargoSha256 = "sha256-f6++5DazCqJjRuZquiJ5hdf9l+q6sOBZOL/vyQy1hA0";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    libxkbcommon
  ];

  doCheck = false;

  meta = with lib; {
    description = "A Solution to your Wayland Wallpaper Woes";
    homepage = "https://github.com/Horus645/swww";
    license = licenses.gpl3;
    maintainers = with maintainers; [ reo101 ];
  };
}
