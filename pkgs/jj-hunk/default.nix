{
  lib,
  fetchFromGitHub,
  rustPlatform,
  git,
  jujutsu,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "jj-hunk";
  version = "0.5.1";

  src = fetchFromGitHub {
    owner = "laulauland";
    repo = finalAttrs.pname;
    tag = "v${finalAttrs.version}";
    hash = "sha256-Pe0rLEUMXmq+8eUMmjuu5KvFJ/aN53bTQ6/1rE2YcT0=";
  };

  cargoHash = "sha256-tO4oGY92AieYb1SY3ylWSkOlcIKadbZLKOY6nTzXo48=";

  nativeCheckInputs = [
    git
    jujutsu
  ];
  cargoTestFlags = [ "--workspace" ];
  preCheck = ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
  '';

  meta = {
    description = "Non-interactive hunk selection and distribution for Jujutsu";
    homepage = "https://github.com/laulauland/jj-hunk";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.reo101 ];
    mainProgram = "jj-hunk";
    platforms = lib.platforms.unix;
  };
})
