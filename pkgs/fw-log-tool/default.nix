{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  python3,
  pciutils,
  usbutils,
  lshw,
  dmidecode,
  iw,
  lm_sensors,
  nvme-cli,
  fwupd,
  upower,
  smartmontools,
  pulseaudio,
  alsa-utils,
  bluez,
  networkmanager,
  iproute2,
  iputils,
  xrandr,
  libdrm,
  mokutil,
  bolt,
  fprintd,
  power-profiles-daemon,
  tlp,
  tuned,
}:

stdenvNoCC.mkDerivation rec {
  pname = "fw-log-tool";
  version = "unstable-2026-07-03";

  src = fetchFromGitHub {
    owner = "FrameworkComputer";
    repo = "linux-docs";
    rev = "faa098b9fd4d027ca47ef33bd5407886687062e7";
    hash = "sha256-Ty20UvhFOu0kLetjxnFWOq0x5qw+g45UJE7E7b2Tn0Y=";
  };

  nativeBuildInputs = [ makeWrapper ];

  runtimeInputs = [
    pciutils
    usbutils
    lshw
    dmidecode
    iw
    lm_sensors
    nvme-cli
    fwupd
    upower
    smartmontools
    pulseaudio
    alsa-utils
    bluez
    networkmanager
    iproute2
    iputils
    xrandr
    libdrm
    mokutil
    bolt
    fprintd
    power-profiles-daemon
    tlp
    tuned
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/${pname} $out/share/doc/${pname} $out/bin
    cp -r fw-log-tool/framework_diagnostic $out/lib/${pname}/
    cp fw-log-tool/README.md $out/share/doc/${pname}/README.md

    substituteInPlace $out/lib/${pname}/framework_diagnostic/dependencies.py \
      --replace-fail "if distro_id == 'nixos':" "if False and distro_id == 'nixos':"

    makeWrapper ${lib.getExe python3} $out/bin/fw-log-tool \
      --add-flags "-m framework_diagnostic" \
      --set PYTHONPATH "$out/lib/${pname}" \
      --prefix PATH : ${lib.makeBinPath runtimeInputs}

    ln -s fw-log-tool $out/bin/fw-diagnostic
    ln -s fw-log-tool $out/bin/fw_diag

    runHook postInstall
  '';

  meta = {
    description = "Framework Linux diagnostic log gathering tool";
    homepage = "https://github.com/FrameworkComputer/linux-docs/tree/main/fw-log-tool";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ reo101 ];
    mainProgram = "fw-log-tool";
    platforms = lib.platforms.linux;
  };
}
