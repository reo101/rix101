{ lib
, buildGoModule
, fetchFromGitHub
, sqlite
, nodejs_20
, pnpm
, fetchPnpmDeps
, pnpmConfigHook
, pkg-config
}:

buildGoModule rec {
  pname = "syncyomi";
  version = "1.1.4";

  src = fetchFromGitHub {
    owner = "syncyomi";
    repo = "syncyomi";
    rev = "v${version}";
    hash = "sha256-pU3zxzixKoYnJsGpfvC/SVWIu0adsaiiVcLn0IZe64w=";
  };

  vendorHash = "sha256-fzPEljXFskr1/qzTsnASFNNc+8vA7kqO21mhMqwT44w=";

  # NOTE: `pnpm` building of the `web` directory
  env.pnpmDeps = fetchPnpmDeps {
    pname = "${pname}-web";
    version = version;
    src = "${src}/web";
    fetcherVersion = 2;
    hash = "sha256-jZi2b+Ng3ebz1xCuEJ+yg52RQTxTytiIanAwq/TH6Xc=";
  };
  env.pnpmRoot = "web";

  nativeBuildInputs = [
    nodejs_20
    pnpm
    # NOTE: uses `env.pnpmDeps` and `env.pnpmRoot` to wire up `PNPM_HOME` and offline store
    pnpmConfigHook
    pkg-config
  ];

  buildInputs = [
    sqlite
  ];

  # NOTE: because of `pnpm.configHook` and `pnpmDeps`, we can now build `web` in the derivation (offilne)
  preBuild = ''
    export HOME="$TMPDIR"
    CI= pnpm --dir web run build
  '';

  # NOTE: embed version info like the upstream GoReleaser config
  #       (not strictly needed but it's a nice-to-have)
  ldflags = [
    "-s" "-w"
    "-X main.version=v${version}"
    "-X main.commit=${src.rev}"
  ];

  # NOTE: the `go.mod` is at the repo root
  subPackages = [ "." ];

  meta = with lib; {
    description = "A self-hosted, FOSS, MangaDex-syncing-and-serving application";
    homepage = "https://github.com/syncyomi/syncyomi";
    license = licenses.mit;
    maintainers = with maintainers; [ reo101 ];
    platforms = platforms.linux;
    mainProgram = "SyncYomi";
  };
}
