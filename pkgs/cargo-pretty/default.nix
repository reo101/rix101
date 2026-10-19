{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage rec {
  pname = "cargo-pretty";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "romancitodev";
    repo = pname;
    tag = "v${version}";
    hash = "sha256-RJ0OTCbvsZ6o5t5hyhOIcWvtyv7q36U7Sit6Bwyy0Oo=";
  };

  cargoHash = "sha256-EjvdAIpUKpOXG7QxO5A9Ahb+S4AfmLY/5Oyq5DT2mzI=";

  meta = with lib; {
    description = "Cargo wrapper with a live, animated status view for build, run and test";
    homepage = "https://github.com/romancitodev/cargo-pretty";
    license = licenses.mit;
    maintainers = with maintainers; [ reo101 ];
    mainProgram = "cargo-pretty";
  };
}
