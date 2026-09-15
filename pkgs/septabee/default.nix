{
  lib,
  stdenv,
  fetchurl,
  _7zz,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  libx11,
  libxcursor,
  libxext,
  libxi,
  libxinerama,
  libxrandr,
  libxrender,
  libxxf86vm,
  libGL,
  vulkan-loader,
  wayland,
  libxkbcommon,
  libdecor,
  pipewire,
  libjack2,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "septabee";
  version = "B_T11";

  src = fetchurl {
    url = "https://septabee.nekoweb.org/important_stuff/SEPTABEE_DOWNLOADS/version_B/septabee_linux_${finalAttrs.version}_offline.7z";
    hash = "sha256-NYbHt7KjgXaosV1CLd1nI76gYpWTTE0NY2stCOTLHdM=";
    curlOptsList = [
      "--user-agent"
      "OpenAI File Downloader, XaiImageApiFetch/1.0"
    ];
  };

  nativeBuildInputs = [
    _7zz
    autoPatchelfHook
    copyDesktopItems
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    libx11
  ];

  # The bundled windowing and audio backends load these with dlopen.
  runtimeDependencies = map lib.getLib [
    libx11
    libxcursor
    libxext
    libxi
    libxinerama
    libxrandr
    libxrender
    libxxf86vm
    libGL
    vulkan-loader
    wayland
    libxkbcommon
    libdecor
    pipewire
    libjack2
  ];

  sourceRoot = "linux";
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
    7zz x "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/libexec/septabee" "$out/bin"
    cp -r . "$out/libexec/septabee/"
    chmod +x "$out/libexec/septabee/"{septabee,septabee-sounds,septabee-watchdawg}
    ln -s "$out/libexec/septabee/septabee" "$out/bin/septabee"
    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "septabee";
      desktopName = "Septabee";
      genericName = "Digital Audio Workstation";
      exec = "septabee";
      categories = [
        "AudioVideo"
        "Audio"
        "Music"
      ];
    })
  ];

  passthru.nixosModule = import ./nixos-module.nix {
    package = finalAttrs.finalPackage;
  };

  meta = {
    description = "Digital audio workstation with a dataflow interface";
    homepage = "https://septabee.nekoweb.org/";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ reo101 ];
    mainProgram = "septabee";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
