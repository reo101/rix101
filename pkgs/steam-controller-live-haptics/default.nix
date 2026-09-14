{
  lib,
  stdenv,
  fetchFromGitHub,
  makeDesktopItem,
  pkg-config,
  hidapi,
  libpulseaudio,
  pulseaudio,
  qt5,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "steam-controller-live-haptics";

  desktopItem = makeDesktopItem {
    name = "livehaptics";
    desktopName = "LiveHaptics";
    comment = "Real-time system-audio haptics for the Steam Controller";
    exec = "/run/wrappers/bin/livehaptics-gui";
    categories = [ "AudioVideo" "Audio" ];
  };
  version = "1.2";

  src = fetchFromGitHub {
    owner = "FamBoy32-dev";
    repo = "steam-controller-live-haptics";
    rev = "ae878560bcd1652132cab4896d91563233178167";
    hash = "sha256-lthHIPzXRZISFefcQuWvBx/32Yfkt2T4i1sS1EptRRw=";
  };

  prePatch = "sed -i 's/\\r$//' haptics.cpp";

  patches = [
    ./patches/0001-fix-linux-capture-startup.patch
    ./patches/0002-fix-gui-launcher.patch
  ];

  nativeBuildInputs = [
    pkg-config
    qt5.wrapQtAppsHook
  ];

  buildInputs = [
    hidapi
    libpulseaudio
    qt5.qtbase
  ];

  postPatch = ''
    # The upstream Git tree omits the Linux capture backends that haptics.cpp
    # includes. Keep the build source-based while supplying those source files.
    cp ${./capture_linux.hpp} capture_linux.hpp
    cp ${./web_linux.hpp} web_linux.hpp
    substituteInPlace gui_qt.cpp \
      --replace-fail @pactl@ ${pulseaudio}/bin/pactl \
      --replace-fail @livehaptics@ $out/bin/livehaptics
  '';

  buildPhase = ''
    runHook preBuild

    $CXX -O2 -std=gnu++23 haptics.cpp -o livehaptics \
      -lhidapi-hidraw -lpulse-simple -lpulse -pthread
    $CXX -O2 -std=gnu++17 -fPIC gui_qt.cpp -o LiveHapticsGUI \
      $(pkg-config --cflags --libs Qt5Widgets) -lhidapi-hidraw

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 livehaptics $out/bin/livehaptics
    install -Dm755 LiveHapticsGUI $out/bin/LiveHapticsGUI
    install -Dm444 ${finalAttrs.desktopItem}/share/applications/livehaptics.desktop \
      $out/share/applications/livehaptics.desktop

    runHook postInstall
  '';

  meta = {
    description = "Real-time system-audio haptics for the Steam Controller";
    homepage = "https://github.com/FamBoy32-dev/steam-controller-live-haptics";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ reo101 ];
    mainProgram = "livehaptics";
    platforms = lib.platforms.linux;
  };
})
