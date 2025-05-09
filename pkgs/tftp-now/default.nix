{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "tftp-now";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "puhitaku";
    repo = "tftp-now";
    rev = version;
    hash = "sha256-D1ryCeusk+/7NZyrYT4rPifesd1ZvP0eXlcyMM8/1Lw=";
  };

  vendorHash = "sha256-9b6uXJALMpbbOgtN9+X8jmr88LiDV8q84b1Wv8Eyhkk=";

  ldflags = [ "-s" "-w" ];


  # FIXME:
  # > Running phase: checkPhase
  # > ok        github.com/puhitaku/tftp-now    0.030s
  # > ok       github.com/puhitaku/tftp-now/server     0.074s
  # > go: failed to trim cache: open /build/go-cache/trim.txt: no such file or directory
  doCheck = false;

  meta = {
    description = "Single-binary TFTP server and client that you can use right now. No package installation, no configuration, no frustration";
    homepage = "https://github.com/puhitaku/tftp-now";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "tftp-now";
  };
}
