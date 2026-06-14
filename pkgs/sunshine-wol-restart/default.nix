{ inputs }:

{
  lib,
  stdenv,
}:

let
  zig = inputs.zig-flake.packages.${stdenv.hostPlatform.system}.default;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "sunshine-wol-restart";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ zig ];

  dontConfigure = true;
  doCheck = true;

  buildPhase = ''
    runHook preBuild
    export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
    export ZIG_LOCAL_CACHE_DIR=$TMPDIR/zig-local-cache
    zig build-exe main.zig -O ReleaseSafe --name sunshine-wol-restart
    runHook postBuild
  '';

  checkPhase = ''
    runHook preCheck
    export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
    export ZIG_LOCAL_CACHE_DIR=$TMPDIR/zig-local-cache
    zig test main.zig
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 sunshine-wol-restart $out/bin/sunshine-wol-restart
    runHook postInstall
  '';

  passthru.services.default = {
    imports = [
      (lib.modules.importApply ./service.nix { })
    ];
    sunshine-wol-restart.package = lib.mkOptionDefault finalAttrs.finalPackage;
  };

  meta = {
    description = "Restart Sunshine user services when a Wake-on-LAN magic packet is seen";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ reo101 ];
    mainProgram = "sunshine-wol-restart";
    platforms = lib.platforms.linux;
  };
})
