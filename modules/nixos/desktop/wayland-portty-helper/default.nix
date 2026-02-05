{
  lib,
  stdenvNoCC,
  babashka,
  clj-kondo,
  coreutils,
  makeWrapper,
  portty,
  zenity,
  helperScript ? ./wayland-portty-helper.clj,
}:

stdenvNoCC.mkDerivation {
  pname = "wayland-portty-helper";
  version = "0.0.1";

  src = helperScript;
  dontUnpack = true;
  doCheck = true;

  nativeBuildInputs = [
    clj-kondo
    makeWrapper
  ];

  installPhase = ''
    mkdir -p $out/bin
    install -m755 $src $out/wayland-portty-helper.clj

    makeWrapper ${lib.getExe babashka} $out/bin/portty-helper \
      --add-flags "--file $out/wayland-portty-helper.clj" \
      --run '
        case "''${0##*/}" in
          sel) export PORTTY_HELPER_INTENT=sel ;;
          submit) export PORTTY_HELPER_INTENT=submit ;;
          portty-session-holder) export PORTTY_HELPER_INTENT=session-holder ;;
          porttyd-wayland-wrapper) export PORTTY_HELPER_INTENT=porttyd-wrapper ;;
        esac
      ' \
      --prefix PATH : ${lib.makeBinPath [ coreutils portty zenity ]}

    ln -s portty-helper $out/bin/sel
    ln -s portty-helper $out/bin/submit
    ln -s portty-helper $out/bin/portty-session-holder
    ln -s portty-helper $out/bin/porttyd-wayland-wrapper
  '';

  checkPhase = ''
    ${lib.getExe clj-kondo} --lint $src \
      --config '{:linters {:namespace-name-mismatch {:level :off}}}'
  '';

  meta = {
    description = "Babashka tools for Portty Wayland integration";
    mainProgram = "portty-helper";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
