{
  lib,
  fetchFromGitHub,
  buildGoModule,
  fetchPnpmDeps,
  pnpmConfigHook,
  writableTmpDirAsHomeHook,
  sqlite,
  nodejs_26,
  pnpm,
  pkg-config,
  formats,
  writeShellScript,
  util-linux,
}:

buildGoModule (finalAttrs: {
  pname = "syncyomi";
  version = "1.1.7";

  src = fetchFromGitHub {
    owner = "syncyomi";
    repo = "syncyomi";
    rev = "v${finalAttrs.version}";
    hash = "sha256-ot8c7+a/YLhjt9HkcI8QZ2ICgtBj3VGJhxtnhWC0f+0=";
  };

  vendorHash = "sha256-7AySGQBQHaTp2M1uj5581ZqcpzgexI1KvanWMOc6rx0=";

  # NOTE: `pnpm` building of the `web` directory
  env.pnpmDeps = fetchPnpmDeps {
    pname = "${finalAttrs.pname}-web";
    inherit (finalAttrs) version;
    src = "${finalAttrs.src}/web";
    fetcherVersion = 3;
    hash = "sha256-o+zfqXkgHE9/3VPrJ0llb6ZRBe2R8J0ROM7xtvCVrv4=";
  };
  env.pnpmRoot = "web";

  nativeBuildInputs = [
    nodejs_26
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

  passthru.services.default = {
    imports = [
      (lib.modules.importApply ./service.nix {
        inherit formats writeShellScript util-linux;
      })
    ];
    syncyomi.package = finalAttrs.finalPackage;
  };

  meta = {
    description = "Self-hosted, FOSS synchronization server for Tachiyomi manga reading progress and library across multiple devices.";
    homepage = "https://github.com/syncyomi/syncyomi";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ reo101 ];
    platforms = lib.platforms.linux;
    mainProgram = "SyncYomi";
  };
})
