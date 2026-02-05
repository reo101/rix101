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
    "zero"
  ],
  enableNerdFont ? true,
  enableCN ? true,
  enableHinting ? false,
  enableLigature ? true,
}:

let
  version = "7.9";

  cnBaseStatic = fetchurl {
    url = "https://github.com/subframe7536/maple-font/releases/download/cn-base/cn-base-static.zip";
    hash = "sha256-HkBRGojXBoWnJ3q0ismVaav0GGuZj+hs0vOGbH8XYvs=";
  };

  ufo-extractor = python3.pkgs.buildPythonPackage rec {
    pname = "ufo-extractor";
    version = "0.8.1";
    format = "wheel";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/cd/cf/34b74c79439ac47ee16e129b709b1fe61ef20211175ac358a252ae50dd3b/ufo_extractor-0.8.1-py2.py3-none-any.whl";
      hash = "sha256-izsLstgfeAIgPpQIUbB85FWbZ9Yn7zMDTou9j61m1ac=";
    };
    dependencies = [ python3.pkgs.fonttools ];
    doCheck = false;
  };

  foundrytools = python3.pkgs.buildPythonPackage rec {
    pname = "foundrytools";
    version = "0.1.4";
    pyproject = true;
    src = python3.pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-pWHSIhj0g1jUs6ij5o2NGcDBrgJDBCXjQyJmSpYOxfo=";
    };
    build-system = [ python3.pkgs.setuptools ];
    dependencies = with python3.pkgs; [
      afdko
      fonttools
      skia-pathops
      brotli
      ttfautohint-py
      dehinter
      ufo2ft
      cffsubr
      ufo-extractor
    ];
    doCheck = false;
  };

  foundrytools-cli = python3.pkgs.buildPythonPackage rec {
    pname = "foundrytools-cli";
    version = "2.0.2";
    pyproject = true;
    src = python3.pkgs.fetchPypi {
      pname = "foundrytools_cli";
      inherit version;
      hash = "sha256-wOs6ka+M4vAvi4ydTdFHRbOvocyjI7gHWJ/n3YrV2Ws=";
    };
    build-system = [ python3.pkgs.hatchling ];
    dependencies = with python3.pkgs; [
      foundrytools
      afdko
      fonttools
      skia-pathops
      brotli
      click
      rich
      loguru
      pathvalidate
    ];
    doCheck = false;
  };

  python-minifier = python3.pkgs.buildPythonPackage rec {
    pname = "python-minifier";
    version = "3.1.0";
    pyproject = true;
    src = python3.pkgs.fetchPypi {
      pname = "python_minifier";
      inherit version;
      hash = "sha256-hbzPmbd1alIdaqO/XwCVDifslIDqYtZu2VW9uO7CTBQ=";
    };
    build-system = [ python3.pkgs.setuptools ];
    doCheck = false;
  };

  pythonEnv = python3.withPackages (ps: with ps; [
    fonttools
    glyphslib
    ttfautohint-py
    brotli
    skia-pathops
    setuptools
    foundrytools-cli
    python-minifier
  ]);
in

stdenvNoCC.mkDerivation {
  pname = "maple-mono-custom";
  inherit version;

  src = fetchFromGitHub {
    owner = "subframe7536";
    repo = "maple-font";
    rev = "v${version}";
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
      featFlag = lib.optionalString (features != [])
        "--feat ${lib.concatStringsSep "," features}";
      hintFlag = if enableHinting then "--hinted" else "--no-hinted";
      ligaFlag = if enableLigature then "--liga" else "--no-liga";
      nfFlag = if enableNerdFont then "--nf" else "--no-nf";
      cnFlag = if enableCN then "--cn" else "--no-cn";
    in
    ''
      runHook preBuild
      python build.py ${featFlag} ${hintFlag} ${ligaFlag} ${nfFlag} ${cnFlag}
      runHook postBuild
    '';

  installPhase = ''
    runHook preInstall
    find fonts -name '*.ttf' -exec install -Dt $out/share/fonts/truetype {} \;
    find fonts -name '*.otf' -exec install -Dt $out/share/fonts/opentype {} \;
    runHook postInstall
  '';

  meta = {
    description = "Maple Mono - custom build with frozen OpenType features";
    homepage = "https://github.com/subframe7536/maple-font";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
}
