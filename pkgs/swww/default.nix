{ lib, fetchFromGitHub, rustPlatform, pkg-config, libxkbcommon }:

rustPlatform.buildRustPackage rec {
  pname = "swww";
  version = "v0.8.0";

  src = fetchFromGitHub {
    owner = "Horus645";
    repo = pname;
    rev = version;
    sha256 = "sha256-0QJlZ8ht6niO+D+G6jO+Ggdgt/0VeO6gquCGL5lS6nM=";
  };

  cargoSha256 = "sha256-ZjFeKh9/kGI8EBVe99jGdLoeA1Pun4aYWwLyMwOJCrU=";

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
