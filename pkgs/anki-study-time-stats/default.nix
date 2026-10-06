{
  lib,
  anki-utils,
  fetchurl,
  unzip,
}:

anki-utils.buildAnkiAddon (finalAttrs: {
  pname = "study-time-stats";
  version = "2.1.4";

  src = fetchurl {
    url = "https://github.com/iamjustkoi/StudyTimeStats/releases/download/v${finalAttrs.version}/StudyTimeStats.ankiaddon";
    hash = "sha256-lr+ahPrAnR38cWI8O7zbkPTginlgXhlwDFeqjaYCe7U=";
  };

  unpackPhase = ''
    runHook preUnpack
    mkdir source
    unzip "$src" -d source
    sourceRoot=source
    runHook postUnpack
  '';

  nativeBuildInputs = [ unzip ];

  meta = {
    description = "Customizable study time and review count statistics for Anki";
    homepage = "https://ankiweb.net/shared/info/1247171202";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ reo101 ];
  };
})
