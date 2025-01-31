{ lib
, fetchFromGitHub
, jujutsu
}:

jujutsu.overrideAttrs (oldAttrs: rec {
  version = "0.26.0-dev";
  src = fetchFromGitHub {
    owner = "pylbrecht";
    repo = "jj";
    rev = "cd53fafb1c14ad139882bd5de9a729d8f9fb5aca";
    hash = "sha256-G2iw9LJX0/iNlXkZoOMX4lyG8YG2fQaX+BFSTGaSquY=";
  };
  cargoDeps = oldAttrs.cargoDeps.overrideAttrs (lib.const {
    name = "${oldAttrs.pname}-${version}-vendor.tar.gz";
    inherit src;
    outputHash = "sha256-ycSHJv95vLlRqMGlcx6yWjrD3MuaAEoct6oK9WcCSdI=";
  });
  # FIXME: manpage doesnt work
  postInstall = '''';
})
