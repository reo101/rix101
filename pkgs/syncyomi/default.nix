{
  lib,
  fetchFromGitHub,
  buildGoModule,
  fetchPnpmDeps,
  pnpmConfigHook,
  writableTmpDirAsHomeHook,
  sqlite,
  nodejs_20,
  pnpm,
  pkg-config,
}:

buildGoModule (finalAttrs: {
  pname = "syncyomi";
  version = "1.1.4";

  src = fetchFromGitHub {
    owner = "syncyomi";
    repo = "syncyomi";
    rev = "v${finalAttrs.version}";
    hash = "sha256-pU3zxzixKoYnJsGpfvC/SVWIu0adsaiiVcLn0IZe64w=";
  };

  vendorHash = "sha256-fzPEljXFskr1/qzTsnASFNNc+8vA7kqO21mhMqwT44w=";

  # NOTE: `pnpm` building of the `web` directory
  env.pnpmDeps = fetchPnpmDeps {
    pname = "${finalAttrs.pname}-web";
    inherit (finalAttrs) version;
    src = "${finalAttrs.src}/web";
    fetcherVersion = 2;
    hash = "sha256-jZi2b+Ng3ebz1xCuEJ+yg52RQTxTytiIanAwq/TH6Xc=";
  };
  env.pnpmRoot = "web";

  nativeBuildInputs = [
    nodejs_20
    pkg-config
    pnpm
    # NOTE: uses `env.pnpmDeps` and `env.pnpmRoot` to wire up `PNPM_HOME` and offline store
    pnpmConfigHook
    writableTmpDirAsHomeHook
  ];

  buildInputs = [
    sqlite
  ];

  # NOTE: because of `pnpm.configHook` and `pnpmDeps`, we can now build `web` in the derivation (offilne)
  preBuild = ''
    CI= pnpm --dir web run build
  '';

  # NOTE: embed version info like the upstream GoReleaser config
  #       (not strictly needed but it's a nice-to-have)
  ldflags = [
    "-s"
    "-w"
    "-X main.version=v${finalAttrs.version}"
    "-X main.commit=${finalAttrs.src.rev}"
  ];

  # NOTE: the `go.mod` is at the repo root
  subPackages = [ "." ];

  meta = {
    description = "Self-hosted, FOSS synchronization server for Tachiyomi manga reading progress and library across multiple devices.";
    homepage = "https://github.com/syncyomi/syncyomi";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ reo101 ];
    platforms = lib.platforms.linux;
    mainProgram = "SyncYomi";
  };
})
