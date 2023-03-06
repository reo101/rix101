{ lib, fetchFromGitHub, rustPlatform, openssl, pkg-config, libxkbcommon }:

rustPlatform.buildRustPackage rec {
  pname = "vim-fmi-cli";
  version = "8a405efc988473a6e9f2ab3016ad1535692efbae";

  src = fetchFromGitHub {
    owner = "AndrewRadev";
    repo = pname;
    rev = version;
    sha256 = "sha256-V+R+B9UR9qHeXaqeEaAD2ngVOZV07LoB36ilVhTpdog=";
  };

  cargoSha256 = "sha256-FRU1JieyxJ2joENueKJqGW1jbiMWLbOL03gqXL9k73o=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [ ];

  PKG_CONFIG_PATH = "${openssl.dev}/lib/pkgconfig";
  LD_LIBRARY_PATH = lib.makeLibraryPath buildInputs;

  doCheck = false;

  meta = with lib; {
    description = " The command-line tool for https://www.vim-fmi.bg";
    homepage = "https://github.com/AndrewRadev/vim-fmi-cli";
    license = licenses.mit;
    maintainers = with maintainers; [ reo101 ];
  };
}
