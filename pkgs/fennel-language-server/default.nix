{ lib, fetchFromGitHub, rustPlatform, openssl, pkg-config, libxkbcommon }:

rustPlatform.buildRustPackage rec {
  pname = "fennel-language-server";
  version = "d0c65db2ef43fd56390db14c422983040b41dd9c";

  src = fetchFromGitHub {
    owner = "rydesun";
    repo = pname;
    rev = version;
    hash = "sha256-KU2MPmgHOS/WesBzCmEoHHXHoDWCyqjy49tmMmZw5BQ=";
  };

  cargoSha256 = "sha256-6q1VXgj0f8jTrVxhgYixow0WxJzx+yKHQPqOGmzTzLo=";

  nativeBuildInputs = [ ];

  buildInputs = [ ];

  doCheck = false;

  meta = with lib; {
    description = "Fennel language server protocol (LSP) support.";
    homepage = "https://github.com/rydesun/fennel-language-server";
    license = licenses.mit;
    maintainers = with maintainers; [ reo101 ];
  };
}
