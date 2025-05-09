{
  lib,
  stdenv,
  fetchFromGitHub,

  # Build helpers
  cmake,
  pkg-config,
  makeWrapper,

  # Build dependencies
  boost,
  gtkmm4,
  gtk4-layer-shell,
  libepoxy,
  libconfig,
  libsysprof-capture,
  xorg,
  pcre2,
  util-linux,
  libselinux,
  libsepol,
  fribidi,
  libthai,
  libdatrie,
  expat,
  lerc,

  # Runtime dependencies
  cava,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "cavaland";
  version = "unstable-2024-06-04";

  src = fetchFromGitHub {
    owner = "simrat39";
    repo = "cavaland";
    rev = "b89db22e9223bf82ec0dede005cb90cdb720e7e1";
    hash = "sha256-TUj/6QhZDvrdDKB6yezfNWWsFu4TJ/AFXjTFvZgO2qQ=";
  };

  postPatch = ''
    find . -type f -name "*.cpp" -o -name "*.hpp" -o -name "*.cfg" | while IFS= read -r file; do
      substituteInPlace $file --replace-warn "/usr/share/cavaland" "$out/share/cavaland"
    done
  '';

  nativeBuildInputs = [
    cmake
    pkg-config
    makeWrapper
  ];

  buildInputs = [
    boost
    gtkmm4
    gtk4-layer-shell
    libepoxy
    libconfig
    libsysprof-capture
    xorg.libXdmcp
    pcre2
    util-linux
    libselinux
    libsepol
    fribidi
    libthai
    libdatrie
    expat
    lerc
  ];

  installPhase = ''
    runHook preInstall

    find .

    mkdir -p $out/bin
    cp ./cavaland $out/bin/
    wrapProgram $out/bin/cavaland --prefix PATH : ${lib.makeBinPath [
      cava
    ]}

    mkdir -p $out/share/cavaland
    cp -r ${finalAttrs.src}/shaders $out/share/cavaland/
    cp ${finalAttrs.src}/example.cfg $out/share/cavaland/

    runHook postInstall
  '';

  meta = {
    description = "Cava embedding on wayland background w/opengl";
    homepage = "https://github.com/simrat39/cavaland";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "cavaland";
    platforms = lib.platforms.all;
  };
})
