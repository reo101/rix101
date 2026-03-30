{ inputs }:
{
  lib,
  pkgs,
  fetchFromGitHub,
}:

let
  pname = "portty";
  version = "0.2.1";
  src = fetchFromGitHub {
    owner = "WERDXZ";
    repo = "portty";
    rev = "v${version}";
    hash = "sha256-Vr2OChMC6Cp2q1+NEDEjmGeiODfn9d27E+mPDhG9CUU=";
  };
  craneLib = inputs.crane.mkLib pkgs;

  commonArgs = {
    inherit pname version src;
    strictDeps = true;
    cargoExtraArgs = "--package portty --package porttyd";

    # Upstream currently gates linux pidfd/fifo APIs behind unstable features.
    RUSTC_BOOTSTRAP = 1;
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
in
craneLib.buildPackage (
  commonArgs
  // {
    inherit cargoArtifacts;

    doCheck = false;

    installPhaseCommand = ''
      runHook preInstall

      install -Dm755 target/release/portty $out/bin/portty
      install -Dm755 target/release/porttyd $out/bin/porttyd
      install -Dm755 target/release/porttyd $out/lib/portty/porttyd

      install -Dm644 misc/tty.portal \
        $out/share/xdg-desktop-portal/portals/tty.portal

      mkdir -p $out/lib/systemd/user
      mkdir -p $out/share/dbus-1/services

      cat > $out/lib/systemd/user/portty.service <<EOF
      [Unit]
      Description=Portty - XDG Desktop Portal for TTY
      After=graphical-session.target

      [Service]
      Type=simple
      ExecStart=$out/lib/portty/porttyd
      Restart=on-failure
      RestartSec=5

      [Install]
      WantedBy=default.target
      WantedBy=graphical-session.target
      EOF

      cat > $out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.tty.service <<EOF
      [D-BUS Service]
      Name=org.freedesktop.impl.portal.desktop.tty
      Exec=$out/lib/portty/porttyd
      SystemdService=portty.service
      EOF

      runHook postInstall
    '';

    meta = with lib; {
      description = "Terminal-driven XDG desktop portal backend";
      homepage = "https://github.com/WERDXZ/portty";
      license = licenses.mit;
      mainProgram = "portty";
      maintainers = with maintainers; [ reo101 ];
      platforms = platforms.linux;
    };
  }
)
