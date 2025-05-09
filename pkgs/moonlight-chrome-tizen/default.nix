{
  lib,
  fetchurl,
  stdenv,
}:

stdenv.mkDerivation rec {
  pname = "moonlight-chrome-tizen";
  version = "samsung_wasm-20232642057";

  src = fetchurl {
    url = "https://github.com/OneLiberty/moonlight-chrome-tizen/releases/download/${version}/Moonlight.wgt";
    hash = "sha256-BNi8yB04x4jJQ2UoQTfuN9J8xcizxQNxJC0Wl3MUzlE=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/tizen-apps
    cp $src $out/share/tizen-apps/Moonlight.wgt

    runHook postInstall
  '';

  meta = with lib; {
    description = "A WASM port of Moonlight for Samsung Smart TV's running Tizen OS (5.5+)";
    homepage = "https://github.com/OneLiberty/moonlight-chrome-tizen";
    longDescription = ''
      Moonlight for Tizen is an open-source client for NVIDIA GameStream and Sunshine.
      It enables streaming games from a powerful desktop to Samsung Smart TVs running
      Tizen OS 5.5 or higher.

      To install on your TV:
      1. Enable Developer Mode: Apps > 12345 > Developer mode > On
      2. Connect: sdb connect <TV_IP>
      3. Install: tizen install -n Moonlight.wgt -t <DEVICE_ID>
    '';
    license = licenses.gpl3;
    maintainers = with maintainers; [ reo101 ];
    platforms = platforms.unix;
  };
}
