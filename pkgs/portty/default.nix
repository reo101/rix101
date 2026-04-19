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

    # Upstream currently requires nightly-only linux pidfd/fifo APIs
    # Scope bootstrap to the daemon crate instead of enabling it workspace-wide
    RUSTC_BOOTSTRAP = "porttyd";
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
in
craneLib.buildPackage (
  commonArgs
  // {
    inherit cargoArtifacts;

    cargoTestExtraArgs = "--package libportty --package portty";

    installPhaseCommand = ''
      runHook preInstall

      install -Dm755 target/release/portty $out/bin/portty
      install -Dm755 target/release/porttyd $out/bin/porttyd

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
