{
  lib,
  python3Packages,
  fetchFromGitHub,
  makeWrapper,
  ffmpeg,
  firewalld,
  glib,
  gst_all_1,
  iproute2,
  networkmanager,
  pulseaudio,
  wf-recorder,
  wirelesstools,
  wpa_supplicant,
  xrandr,
}:

python3Packages.buildPythonApplication rec {
  pname = "fluxcast";
  version = "0.1.5";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "IlyaP358";
    repo = "fluxcast";
    rev = "38fdbc249056d1512114273e09410583fb2678e0";
    hash = "sha256-5o1uw2Mo9YT4tD8/u4hq3MjeUcMy7djhWgWDVx0aiSw=";
  };

  nativeBuildInputs = [
    makeWrapper
    python3Packages.hatchling
  ];

  propagatedBuildInputs = with python3Packages; [
    dbus-next
    pillow
    pychromecast
    pygobject3
    pystray
    upnpclient
  ];

  pythonImportsCheck = [
    "cast"
    "dlna"
    "main"
    "portal_capture"
  ];

  postInstall = ''
    install -Dm444 meta/fluxcast.desktop -t $out/share/applications

    wrapProgram $out/bin/fluxcast \
      --prefix PATH : ${lib.makeBinPath [
        ffmpeg
        firewalld
        glib
        gst_all_1.gstreamer
        iproute2
        networkmanager
        pulseaudio
        wf-recorder
        wirelesstools
        wpa_supplicant
        xrandr
      ]} \
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" [
        gst_all_1.gst-plugins-base
        gst_all_1.gst-plugins-good
        gst_all_1.gst-plugins-bad
        gst_all_1.gst-plugins-ugly
        gst_all_1.gst-libav
      ]}
  '';

  meta = {
    description = "Stream your Linux desktop to a Smart TV via Miracast/WFD, DLNA, or Chromecast";
    homepage = "https://github.com/IlyaP358/fluxcast";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ reo101 ];
    mainProgram = "fluxcast";
    platforms = lib.platforms.linux;
  };
}
