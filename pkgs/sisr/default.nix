{ inputs }:
{
  lib,
  pkgs,
  fetchFromGitHub,
  fetchNpmDeps,
  npm-lockfile-fix,
  npmHooks,
  nodejs,
  cmake,
  ninja,
  pkg-config,
  patchelf,
  addDriverRunpath,
  wrapGAppsHook3,
  glib,
  glib-networking,
  gtk3,
  webkitgtk_4_1,
  libsoup_3,
  librsvg,
  libayatana-appindicator,
  xdotool,
  libX11,
  libXext,
  libXcursor,
  libXi,
  libXfixes,
  libXrandr,
  libXrender,
  libXScrnSaver,
  libXtst,
  alsa-lib,
  libpulseaudio,
  pipewire,
  vulkan-loader,
  wayland,
  libxkbcommon,
}:

let
  craneLib = inputs.crane.mkLib pkgs;

  pname = "sisr";
  version = "0.0.1-unstable-2026-05-16";
  rev = "1dd961803eabc4cb20840458828842ccf12dbb2e";

  src = fetchFromGitHub {
    owner = "Alia5";
    repo = "SISR";
    inherit rev;
    postFetch = ''
      ${lib.getExe npm-lockfile-fix} "$out/CEF_Payloads/package-lock.json"
      ${lib.getExe npm-lockfile-fix} "$out/UI/package-lock.json"
    '';
    hash = "sha256-eAClJpHGQnY15WYKPY36wBUJWsiysvWFOMZMun0Xy0w=";
  };

  npmDepsCEF = fetchNpmDeps {
    name = "${pname}-${version}-cef-payloads-npm-deps";
    src = "${src}/CEF_Payloads";
    hash = "sha256-SziXnM6B/H1/bM+M5U/VO1P23CuoerGWM0IULpEVVec=";
    fetcherVersion = 2;
  };

  npmDepsUI = fetchNpmDeps {
    name = "${pname}-${version}-ui-npm-deps";
    src = "${src}/UI";
    hash = "sha256-1TSdlAxDcmrXZOy2/PFKQewdZMkYb7p1VOwUI4MvyKM=";
    fetcherVersion = 2;
  };

  cargoNativeBuildInputs = [
    cmake
    ninja
    pkg-config
  ];

  buildInputs = [
    glib
    glib-networking
    gtk3
    webkitgtk_4_1
    libsoup_3
    librsvg
    libayatana-appindicator
    xdotool
    libX11
    libXext
    libXcursor
    libXi
    libXfixes
    libXrandr
    libXrender
    libXScrnSaver
    libXtst
    alsa-lib
    libpulseaudio
    pipewire
    vulkan-loader
    wayland
    libxkbcommon
  ];

  commonArgs = {
    inherit
      pname
      version
      src
      buildInputs
      ;

    strictDeps = true;

    env = {
      SISR_VERSION = version;
      PUBLIC_LOG_LEVEL = "info";
    };

    nativeBuildInputs = cargoNativeBuildInputs;

    # HACK: those are needed by build scripts for bundled native deps,
    #       but their setup hooks must not take over the Rust package phases
    dontUseCmakeConfigure = true;
    dontUseNinjaBuild = true;
    dontUseNinjaInstall = true;
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
in
craneLib.buildPackage (
  commonArgs
  // {
    inherit cargoArtifacts;

    nativeBuildInputs = cargoNativeBuildInputs ++ [
      patchelf
      nodejs
      wrapGAppsHook3
    ];

    patches = [
      ./patches/0001-desktop-launch-windowed.patch
      ./patches/0002-stable-marker-shortcut-path.patch
    ];

    # NOTE:
    # - SISR contains two separate `npm` projects that are built before `Cargo`
    #   so their generated assets can be embedded by the Rust build
    # - `npmConfigHook` is a normal setup hook and only handles one `npmRoot`,
    #   so we have to run it explicitly for each subproject here
    #   instead of plainly adding it to `nativeBuildInputs`
    # - Keep this in a subshell with an empty `postPatchHooks` array so
    #   sourcing the hook does not recursively run the global post-patch hooks
    # - The cache is cleared between workspaces because `npmConfigHook` reuses
    #   `$TMPDIR/cache`
    postPatch = ''
      (
        local postPatchHooks=()
        source ${npmHooks.npmConfigHook}/nix-support/setup-hook
        npmRoot=CEF_Payloads npmDeps=${npmDepsCEF} npmConfigHook
        rm -rf "$TMPDIR/cache"
        npmRoot=UI npmDeps=${npmDepsUI} npmConfigHook
      )
    '';

    preBuild = ''
      npm --prefix CEF_Payloads run build
      npm --prefix UI run build
    '';

    preFixup = ''
      gappsWrapperArgs+=(
        --set SISR_EXECUTABLE_PATH "$out/bin/SISR"
        --prefix LD_LIBRARY_PATH : ${
          lib.makeLibraryPath [
            libayatana-appindicator
            libxkbcommon
            vulkan-loader
          ]
        }:${addDriverRunpath.driverLink}/lib
      )
    '';

    postInstall = ''
      install -Dm644 sisr.desktop "$out/share/applications/sisr.desktop"
      install -Dm644 docs/SISR.svg "$out/share/icons/hicolor/scalable/apps/SISR.svg"

      # HACK:
      # - Upstream enables `sdl3-sys/build-from-source`, so Cargo builds `SDL3`
      #   from the vendored `sdl3-src` crate instead of linking against a
      #   system `SDL3`
      # - The resulting binary expects that exact `libSDL3.so.0` at runtime,
      #   so install the library produced by the Cargo build
      #   and add `$out/lib` to the executable `RPATH` in `postFixup` below
      sdl3_lib="$(find target -name libSDL3.so.0 -type f | head -n 1)"
      if [ -z "$sdl3_lib" ]; then
        echo "Could not find built libSDL3.so.0" >&2
        exit 1
      fi
      install -Dm755 "$sdl3_lib" "$out/lib/libSDL3.so.0"
      ln -s libSDL3.so.0 "$out/lib/libSDL3.so"
    '';

    postFixup = ''
      binary="$out/bin/SISR"
      if [ -e "$out/bin/.SISR-wrapped" ]; then
        binary="$out/bin/.SISR-wrapped"
      fi
      patchelf --add-rpath "$out/lib" "$binary"
    '';

    doCheck = false;

    meta = {
      description = "Steam Input System Redirector";
      homepage = "https://github.com/Alia5/SISR";
      license = lib.licenses.gpl3Only;
      maintainers = [ lib.maintainers.reo101 ];
      mainProgram = "SISR";
      platforms = lib.platforms.linux;
    };
  }
)
