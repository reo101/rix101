{
  fetchFromGitHub,
  callPackage,
  rustPlatform,
  ...
}:

let
  version = "0.2.9";
  src = fetchFromGitHub {
    owner = "rustonbsd";
    repo = "iroh-ssh";
    rev = version;
    hash = "sha256-0G2RZbxyxi96FpVPEamfcTrOgPxpFYHmyYg1kQfo7TQ=";
  };
  pkg = callPackage "${src}/nix/package.nix" { };
in
  pkg.overrideAttrs (oldAttrs: {
    inherit version src;
    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit src;
      name = "iroh-ssh-${version}-vendor";
      hash = "sha256-2/hc1K6zUyQlWorZh34HP9PCdV4YD1ob9l1DFiW7c1Y=";
    };
  })
