{
  lib,
  stdenv,
  zig,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "osu-touchpad";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./build.zig
      ./src
      ./service.nix
    ];
  };

  nativeBuildInputs = [ zig ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
    export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"
    zig build -Doptimize=ReleaseSafe
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 zig-out/bin/osu-touchpad $out/bin/osu-touchpad
    runHook postInstall
  '';

  passthru.services.default = {
    imports = [
      (lib.modules.importApply ./service.nix { })
    ];
    osu-touchpad.package = lib.mkOptionDefault finalAttrs.finalPackage;
  };

  meta = {
    description = "Map the Framework 16 touchpad to an absolute osu! tablet via evdev/uinput";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ reo101 ];
    mainProgram = "osu-touchpad";
    platforms = lib.platforms.linux;
  };
})
