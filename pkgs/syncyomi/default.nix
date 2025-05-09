{ lib
, buildGoModule
, fetchFromGitHub
, sqlite
, nodejs_20
, pnpm
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

  # Go modules vendoring (for buildGoModule)
  vendorHash = "sha256-fzPEljXFskr1/qzTsnASFNNc+8vA7kqO21mhMqwT44w=";

  # ---- Frontend vendoring (pnpm) in a separate fixed-output derivation ----
  # This prefetches the pnpm store for web/pnpm-lock.yaml
  pnpmDeps = pnpm.fetchDeps {
    pname = "${pname}-web";
    version = version;
    src = "${src}/web";
    fetcherVersion = 2;
    hash = "sha256-jZi2b+Ng3ebz1xCuEJ+yg52RQTxTytiIanAwq/TH6Xc=";
  };
  pnpmRoot = "web";

  nativeBuildInputs = [
    nodejs_20
    pnpm
    # NOTE: uses `pnpmDeps` and `pnpmRoot` to wire up `PNPM_HOME` and offline store
    pnpm.configHook
    pkg-config
  ];

  buildInputs = [
    sqlite
  ];

  # buildGoModule sets GOPATH, etc. We just need to build the web assets before `go build`.
  # With pnpm.configHook and pnpmDeps, this runs fully offline.
  preBuild = ''
    export HOME="$TMPDIR"
    CI= pnpm --dir web run build
  '';

  # Embed version info like the upstream GoReleaser config
  ldflags = [
    "-s" "-w"
    "-X main.version=v${version}"
    "-X main.commit=${src.rev}"
  ];

  # The go.mod is at repo root
  subPackages = [ "." ];

  # NOTE: could be needed because of `sqlite`
  # CGO_ENABLED = 1;

  doCheck = false;  # often disabled for binaries that don’t ship tests in tree; flip if tests exist

  meta = with lib; {
    description = "A self-hosted, FOSS, MangaDex-syncing-and-serving application";
    homepage = "https://github.com/syncyomi/syncyomi";
    license = licenses.mit;
    maintainers = with maintainers; [ reo101 ];
    platforms = platforms.linux; # realistically, since sqlite/cgo
    mainProgram = "SyncYomi";
  };
}
