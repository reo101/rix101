{
  lib,
  stdenvNoCC,
  coreutils,
  iproute2,
  iputils,
  nushell,
  util-linux,
  testers,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "netpath";
  version = "0.1.0";

  src = ./netpath.nu;
  dontUnpack = true;
  doCheck = true;

  nativeBuildInputs = [ nushell ];

  installPhase = ''
        runHook preInstall

        install -Dm755 $src $out/libexec/netpath.nu
        mkdir -p $out/bin
        cat > $out/bin/netpath <<'EOF'
    #!${stdenvNoCC.shell}
    set -eu
    export PATH=${
      lib.makeBinPath [
        coreutils
        iproute2
        iputils
      ]
    }:$PATH

    case "''${1:-}" in
      ""|status|self-test)
        exec ${lib.getExe nushell} --no-config-file @out@/libexec/netpath.nu "$@"
        ;;
    esac

    if [ "$(${lib.getExe' coreutils "id"} -u)" -ne 0 ]; then
      exec ${lib.getExe nushell} --no-config-file @out@/libexec/netpath.nu "$@"
    fi
    exec ${lib.getExe' util-linux "flock"} /run/lock/netpath.lock \
      ${lib.getExe nushell} --no-config-file @out@/libexec/netpath.nu "$@"
    EOF
        substituteInPlace $out/bin/netpath --replace-fail @out@ "$out"
        chmod 755 $out/bin/netpath

        runHook postInstall
  '';

  checkPhase = ''
    runHook preCheck
    test "$(${lib.getExe nushell} --no-config-file -c "nu-check $src")" = true
    ${lib.getExe nushell} --no-config-file $src self-test
    runHook postCheck
  '';

  passthru = {
    nixosTest = testers.runNixOSTest (import ./nixos-test.nix {
      netpath = finalAttrs.finalPackage;
    });
  };

  meta = {
    description = "Make-before-break IPv4 handover across interfaces on one LAN";
    mainProgram = "netpath";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ reo101 ];
  };
})
