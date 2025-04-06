{ lib
, stdenvNoCC
, babashka
, clj-kondo
, libnotify
, makeWrapper
, batteryScript ? ./battery-notify.clj
}:

stdenvNoCC.mkDerivation {
  pname = "battery-notify";
  version = "0.0.1";

  src = batteryScript;
  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
  ];
  buildInputs = [
    clj-kondo
    libnotify
  ];

  installPhase = ''
    mkdir -p $out/bin
    install -m755 $src $out/battery-notify.clj
    makeWrapper ${lib.getExe babashka} $out/bin/battery-notify \
      --add-flags "--file $out/battery-notify.clj" \
      --set PATH ${lib.makeBinPath [ libnotify ]}
  '';

  checkPhase = ''
    echo "Running clj-kondo linting..."
    ${lib.getExe clj-kondo} --lint $src \
      --config '{:linters {:namespace-name-mismatch {:level :off}}}'
  '';

  meta = {
    description = "Battery notification script using Babashka";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
