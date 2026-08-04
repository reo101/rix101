{ inputs }:
{
  lib,
  pkgs,
  fetchFromGitHub,
}:

let
  pname = "portty";
  version = "0.3.3";
  src = fetchFromGitHub {
    owner = "WERDXZ";
    repo = "portty";
    rev = "v${version}";
    hash = "sha256-7j/uL3Bc2XHZXv/nPi7apZQ5Ql2RL4GgggEOWKXRS0c=";
  };
  craneLib = inputs.crane.mkLib pkgs;

  commonArgs = {
    inherit pname version src;
    strictDeps = true;
    cargoExtraArgs = "--package portty --package porttyd";

    # HACK: bootstrap until upstream supports stable Rust
    preBuild = "export RUSTC_BOOTSTRAP=1";
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
