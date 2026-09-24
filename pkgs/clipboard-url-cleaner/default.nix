{
  lib,
  stdenvNoCC,
  python3,
  wl-clipboard,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "clipboard-url-cleaner";
  version = "0.1.0";

  src = ./clipboard-url-cleaner.py;
  dontUnpack = true;
  doCheck = true;
  nativeBuildInputs = [ python3 ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    printf '#!%s\n' ${lib.getExe python3} > "$out/bin/clipboard-url-cleaner"
    substitute "$src" "$out/bin/clipboard-url-cleaner.tmp" \
      --subst-var-by wlCopy ${lib.getExe' wl-clipboard "wl-copy"}
    cat "$out/bin/clipboard-url-cleaner.tmp" >> "$out/bin/clipboard-url-cleaner"
    rm "$out/bin/clipboard-url-cleaner.tmp"
    chmod +x "$out/bin/clipboard-url-cleaner"
    runHook postInstall
  '';

  checkPhase = ''
    runHook preCheck
    ${lib.getExe python3} "$src" --self-test
    runHook postCheck
  '';

  passthru.services.default = {
    imports = [ (lib.modules.importApply ./service.nix { inherit wl-clipboard; }) ];
    clipboard-url-cleaner.package = lib.mkOptionDefault finalAttrs.finalPackage;
  };

  meta = {
    description = "Remove tracking parameters from URLs copied on Wayland";
    homepage = "https://gist.github.com/cisc0disco/8afb01ebed5e4251e494ba867fccb6c7";
    maintainers = with lib.maintainers; [ reo101 ];
    mainProgram = "clipboard-url-cleaner";
    platforms = lib.platforms.linux;
  };
})
