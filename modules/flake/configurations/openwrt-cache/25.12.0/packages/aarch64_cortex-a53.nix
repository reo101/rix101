import ./common.nix {
  release = "25.12.0";
  arch = "aarch64_cortex-a53";
  sha256sumsHash = "sha256-tU4J8Tdb8IPdHVGMEkCMX1x+g//oKcVXBbskDhEknTs=";
  feedHashes = {
    base = "sha256-fQj4LcxldDktvkXLDLIajwJZdTPuiLiBVKE+542OjBE=";
    luci = "sha256-3hpQi74AgISF4ZzgIfT3ecm1W44+gAf3iLf+xdCIhp4=";
    packages = "sha256-qswVawIybjw1aMGvVHXysypcB2MPmRxr8kVaAxZegkg=";
    routing = "sha256-p92Mt32tkShbcWxyrIq6Kkz30Xtqe17bIqiRBQgaDS8=";
    telephony = "sha256-4rabIeaVDbJa+7+WFT60uO4GOVtX5H9qc6tPDSj75dU=";
  };
}
