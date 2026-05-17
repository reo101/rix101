{
  lib,
  fetchFromGitHub,
  buildGoModule,
  makeWrapper,
  linuxPackages,
}:

buildGoModule (finalAttrs: {
  pname = "viiper";
  version = "0.6.1-unstable-2026-05-18";
  rev = "904bef3a308c13e3c20e57597635d6fd19f4bb58";

  src = fetchFromGitHub {
    owner = "Alia5";
    repo = "VIIPER";
    inherit (finalAttrs) rev;
    hash = "sha256-e26MvotnItVPZpQPoW5YmAtgfXvs/KU7YfcarDB4f24=";
  };

  vendorHash = "sha256-e3am+9f78M/iqW9HLweBCORuLjBVSFrbITZoaJ/6Cow=";

  nativeBuildInputs = [
    makeWrapper
  ];

  env.CGO_ENABLED = 0;

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${finalAttrs.version}"
    "-X main.Commit=${finalAttrs.rev}"
    "-X main.Date=2026-05-18"
    "-X github.com/Alia5/VIIPER/internal/codegen/common.Version=${finalAttrs.version}"
  ];

  subPackages = [ "cmd/viiper" ];

  postInstall = ''
    wrapProgram "$out/bin/viiper" \
      --prefix PATH : ${lib.makeBinPath [ linuxPackages.usbip ]}
  '';

  passthru.services.default = {
    imports = [
      (lib.modules.importApply ./service.nix { })
    ];
    viiper.package = lib.mkOptionDefault finalAttrs.finalPackage;
  };

  meta = {
    description = "Virtual Input over IP EmulatoR";
    homepage = "https://github.com/Alia5/VIIPER";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ reo101 ];
    mainProgram = "viiper";
    platforms = lib.platforms.linux;
  };
})
