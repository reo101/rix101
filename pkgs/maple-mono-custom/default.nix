{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchurl,
  python3,

  enableNerdFont ? true,
  enableCN ? true,
  enableHinting ? false,
  enableLigature ? true,
  # Frozen OpenType features (e.g. cvXX, ssXX)
  features ? [
    "cv03"
    "cv08"
    "cv61"
    "cv64"
    "ss07"
    "ss08"
    "ss09"
    "ss10"
    "zero"
  ],
  # Glyph names for characters that trigger thinned backslash (e.g. "one" for \1)
  extraEscapeChars ? [
    "zero"
    "one"
    "two"
    "three"
    "four"
    "five"
    "six"
    "seven"
    "eight"
    "nine"
  ],
  # Keywords to turn into pills (e.g. `["TASK" "DONE"]`).
  # Built-in tags are left alone; unknown keywords get a composed `.bg` tag.
  pillKeywords ? [
    "TODO"
    "TASK"
    "FIXME"
    "BUG"
  ],
  # Remove alt pill syntax (`todo))`)
  disableAltPill ? true,
  # Cap style for custom tags: block, circle, or sharp
  pillStyle ? "block",
  # Build only Regular / Bold / Italic / BoldItalic
  leastStyles ? true,
  # Build one specific subfamily (e.g. "Regular"); overrides leastStyles
  buildStyle ? null,
}:

let
  ps = python3.pkgs;

  cjkBaseStatic = fetchurl {
    url = "https://github.com/subframe7536/maple-font/releases/download/cjk-base/cn-base-static.zip";
    hash = "sha256-BF7VCQEpCi5DMhpvTpVyn6r+w7yKZXWFU8/xRs7ZAs4=";
  };

  pythonEnv = python3.withPackages (
    ps: with ps; [
      brotli
      fontmake
      fonttools
      glyphslib
      hy
      py7zr
      skia-pathops
      ttfautohint-py
    ]
  );

  outDir =
    if enableNerdFont && enableCN then
      "NF-CN"
    else if enableNerdFont then
      "NF"
    else if enableCN then
      "CN"
    else if enableHinting then
      "TTF-AutoHint"
    else
      "TTF";

  fontName =
    "Maple Mono"
    + lib.optionalString (!enableLigature) " NL"
    + lib.optionalString enableNerdFont " NF"
    + lib.optionalString enableCN " CN";

  patchConfig = {
    style = buildStyle;
    leastStyles = if buildStyle == null then leastStyles else false;
    extraEscape = extraEscapeChars;
    pillKeywords = pillKeywords;
    disableAltPill = disableAltPill;
    pillStyle = pillStyle;
    features = features;
    hinted = enableHinting;
    ligature = enableLigature;
    nerdFont = enableNerdFont;
    cjk = enableCN;
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "maple-mono-custom";
  version = "8.0-beta.3";

  src = fetchFromGitHub {
    owner = "subframe7536";
    repo = "maple-font";
    rev = "v${finalAttrs.version}";
    hash = "sha256-Nra2oje4qFFAb6eS/S2pu/dIx+uZmNErlMCYCo3NA78=";
  };

  nativeBuildInputs = [ pythonEnv ];

  postUnpack = ''
    cp ${./patch_maple.hy} $sourceRoot/patch_maple.hy
  ''
  + lib.optionalString enableCN ''
    cp ${cjkBaseStatic} $sourceRoot/cn-base-static.zip
  '';

  buildPhase = ''
    runHook preBuild
    hy patch_maple.hy ${lib.escapeShellArg (builtins.toJSON patchConfig)}
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    test -d "fonts/${outDir}" || {
      echo "Expected output dir fonts/${outDir} not found"
      exit 1
    }

    find "fonts/${outDir}" -maxdepth 1 -type f -name '*.ttf' \
      -exec install -Dm444 -t "$out/share/fonts/truetype" {} \;

    runHook postInstall
  '';

  passthru = {
    inherit fontName outDir;
  };

  meta = {
    description = "Maple Mono - custom build with frozen OpenType features";
    homepage = "https://github.com/subframe7536/maple-font";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
})
