{ stdenv, uiua, ... }:

stdenv.mkDerivation {
  name = "git-credential-env";
  src = ./git-credential-env.ua;
  nativeBuildInputs = [ uiua ];
  dontUnpack = true;
  dontConfigure = true;
  # uiua stand embeds the source inside the binary; stdenv's strip
  # corrupts that section (runtime silently falls back to watch mode)
  dontStrip = true;
  dontFixup = true;
  buildPhase = ''
    uiua stand "$src" -o git-credential-env
  '';
  installPhase = ''
    install -Dm755 git-credential-env -t $out/bin
  '';
  meta = {
    description = "Git credential helper reading GIT_USERNAME and GIT_PASSWORD";
    mainProgram = "git-credential-env";
  };
}
