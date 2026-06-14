{
  callPackage,
  rustPlatform,
  ...
}:

let
  version = "0.2.9";
  # NOTE: not using `fetchFromGitHub`, since that required `IFD`
  src = builtins.fetchTarball {
    url = "https://github.com/rustonbsd/iroh-ssh/archive/${version}.tar.gz";
    sha256 = "sha256-0G2RZbxyxi96FpVPEamfcTrOgPxpFYHmyYg1kQfo7TQ=";
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
