{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  writers,
  python3Packages,
  nix,
  curl,
  sqlite,
  libmediainfo,
  chromaprint,
  icu,
  openssl,
  zlib,
  stdenv,
}:

let
  pname = "lidarr-nightly";
  version = "3.1.2.4928";
  src = fetchurl {
    url = "https://dev.azure.com/Lidarr/Lidarr/_apis/build/builds/4888/artifacts?artifactName=Packages&fileId=21E0D067BC89CCB785C0F0287F83B8D67EBE8DCABA42CF5DE113C32078E14D7702&fileName=Lidarr.develop.${version}.linux-core-x64.tar.gz&api-version=5.1";
    hash = "sha256-PGYDM2teEn9jYfVdenGxmZZO9XY2FAYCiIFRivfuFxg=";
  };
in
stdenvNoCC.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [ makeWrapper ];

  unpackPhase = ''
    runHook preUnpack
    tar -xzf "$src"
    sourceRoot=Lidarr
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/share/${pname}"
    cp -r . "$out/share/${pname}/"
    chmod +x "$out/share/${pname}/Lidarr"

    makeWrapper "$out/share/${pname}/Lidarr" "$out/bin/Lidarr" \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          stdenv.cc.cc.lib
          curl
          sqlite
          libmediainfo
          chromaprint
          icu
          openssl
          zlib
        ]
      }

    runHook postInstall
  '';

  passthru = {
    updateScript = writers.writePython3 "lidarr-nightly-update" {
      libraries = with python3Packages; [ requests ];
      flakeIgnore = [ "E501" ];
      # NOTE: for the `nix hash` helper
      makeWrapperArgs = [
        "--prefix"
        "PATH"
        ":"
        (lib.makeBinPath [ nix ])
      ];
    } ./update.py;
  };

  meta = {
    description = "Usenet/BitTorrent music downloader (prerelease build with plugin support)";
    homepage = "https://lidarr.audio";
    license = lib.licenses.gpl3Only;
    mainProgram = "Lidarr";
    maintainers = [ lib.maintainers.reo101 ];
    platforms = [ "x86_64-linux" ];
  };
}
