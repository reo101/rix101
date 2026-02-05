{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchurl,
  unzip,
  python3,

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
  enableNerdFont ? true,
  enableCN ? true,
  enableHinting ? false,
  enableLigature ? true,
}:

let
  ps = python3.pkgs;

  cnBaseStatic = fetchurl {
    url = "https://github.com/subframe7536/maple-font/releases/download/cn-base/cn-base-static.zip";
    hash = "sha256-HkBRGojXBoWnJ3q0ismVaav0GGuZj+hs0vOGbH8XYvs=";
  };

  ufo-extractor = ps.buildPythonPackage (finalAttrs: {
    pname = "ufo-extractor";
    version = "0.8.1";
    format = "wheel";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/cd/cf/34b74c79439ac47ee16e129b709b1fe61ef20211175ac358a252ae50dd3b/ufo_extractor-0.8.1-py2.py3-none-any.whl";
      hash = "sha256-izsLstgfeAIgPpQIUbB85FWbZ9Yn7zMDTou9j61m1ac=";
    };
    dependencies = [
      ps.fonttools
      ps.fontfeatures
    ];
    doCheck = false;
  });

  foundrytools = ps.buildPythonPackage (finalAttrs: {
    pname = "foundrytools";
    version = "0.1.4";
    pyproject = true;
    src = ps.fetchPypi {
      inherit (finalAttrs) pname version;
      hash = "sha256-pWHSIhj0g1jUs6ij5o2NGcDBrgJDBCXjQyJmSpYOxfo=";
    };
    build-system = [ ps.setuptools ];
    dependencies = [
      ps.afdko
      ps.fonttools
      ps.skia-pathops
      ps.brotli
      ps.ttfautohint-py
      ps.dehinter
      ps.ufo2ft
      ps.cffsubr
      ufo-extractor
    ];
    doCheck = false;
  });

  foundrytools-cli = ps.buildPythonPackage (finalAttrs: {
    pname = "foundrytools-cli";
    version = "2.0.2";
    pyproject = true;
    src = ps.fetchPypi {
      pname = "foundrytools_cli";
      inherit (finalAttrs) version;
      hash = "sha256-wOs6ka+M4vAvi4ydTdFHRbOvocyjI7gHWJ/n3YrV2Ws=";
    };
    build-system = [ ps.hatchling ];
    dependencies = [
      foundrytools
      ps.afdko
      ps.fonttools
      ps.skia-pathops
      ps.brotli
      ps.click
      ps.rich
      ps.loguru
      ps.pathvalidate
    ];
    doCheck = false;
  });

  python-minifier = ps.buildPythonPackage (finalAttrs: {
    pname = "python-minifier";
    version = "3.1.0";
    pyproject = true;
    src = ps.fetchPypi {
      pname = "python_minifier";
      inherit (finalAttrs) version;
      hash = "sha256-hbzPmbd1alIdaqO/XwCVDifslIDqYtZu2VW9uO7CTBQ=";
    };
    build-system = [ ps.setuptools ];
    doCheck = false;
  });

  pythonEnv = python3.withPackages (ps: [
    ps.fonttools
    ps.glyphslib
    ps.ttfautohint-py
    ps.brotli
    ps.skia-pathops
    ps.setuptools
    foundrytools-cli
    python-minifier
  ]);
in

stdenvNoCC.mkDerivation (
  finalAttrs:
  let
    no = bool: lib.optionalString (!bool) "no-";

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
      "Maple Mono" + lib.optionalString enableNerdFont " NF" + lib.optionalString enableCN " CN";
  in
  {
    pname = "maple-mono-custom";
    version = "7.9";

    src = fetchFromGitHub {
      owner = "subframe7536";
      repo = "maple-font";
      rev = "v${finalAttrs.version}";
      hash = "sha256-wsaE54TeI2EI9VO9Q7Czv9soScGomYIfrllhQQHey2E=";
    };

    nativeBuildInputs = [
      pythonEnv
      unzip
    ];

    postUnpack = lib.optionalString enableCN ''
      mkdir -p $sourceRoot/source/cn/static
      ${lib.getExe unzip} ${cnBaseStatic} -d $sourceRoot/source/cn/static
    '';

    buildPhase =
      let
        featFlag =
          lib.optionalString (features != [ ])
            "--feat ${
              lib.pipe features [
                (lib.map lib.escapeShellArg)
                (lib.concatStringsSep ",")
              ]
            }";
      in
      # bash
      ''
        runHook preBuild
        python build.py ${featFlag} --${no enableHinting}hinted --${no enableLigature}liga --${no enableNerdFont}nf --${no enableCN}cn
        runHook postBuild
      '';

    installPhase =
      # bash
      ''
        runHook preInstall

        test -d "fonts/${outDir}" || { echo "Expected output dir fonts/${outDir} not found"; exit 1; }

        find "fonts/${outDir}" -maxdepth 1 -type f -name '*.ttf' \
          -exec install -Dm444 -t "$out/share/fonts/truetype" {} \;
        find "fonts/${outDir}" -maxdepth 1 -type f -name '*.otf' \
          -exec install -Dm444 -t "$out/share/fonts/opentype" {} \;

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
  }
)
