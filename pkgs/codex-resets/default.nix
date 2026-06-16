{
  lib,
  fetchurl,
  makeWrapper,
  nushell,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "codex-resets";
  version = "0-unstable-2026-07-01";

  src = fetchurl {
    url = "https://gist.githubusercontent.com/archcorsair/c988c34f80daf24d6398c379707909f6/raw/cb94b64cb90b573bccc17fa27b387cde08ac3286/code-resets.nu";
    hash = "sha256-a6eNKT6kURO02mfAq4iD7ngsgGng2aWxWAAqSWgBmQA=";
  };

  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    install -Dm644 $src $out/share/codex-resets/code-resets.nu
    cat > $out/share/codex-resets/codex-resets.nu <<EOF
    source $out/share/codex-resets/code-resets.nu

    def main [
      --raw(-r)
      --codex-home: path
      --auth: path
    ] {
      codex-resets --raw=\$raw --codex-home=\$codex_home --auth=\$auth
    }
    EOF

    makeWrapper ${lib.getExe nushell} $out/bin/codex-resets \
      --add-flags "-n" \
      --add-flags "$out/share/codex-resets/codex-resets.nu"

    runHook postInstall
  '';

  meta = {
    description = "Show Codex reset credits from Codex auth data";
    homepage = "https://gist.github.com/archcorsair/c988c34f80daf24d6398c379707909f6";
    mainProgram = "codex-resets";
    maintainers = [ lib.maintainers.reo101 ];
    platforms = lib.platforms.all;
  };
}
