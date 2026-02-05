import ./common.nix {
  release = "25.12.0";
  arch = "mips_24kc";
  sha256sumsHash = "sha256-LNZgx+3esnSNC27vcX9z9jIRST1VXQOfB0qetWaNVlA=";
  feedHashes = {
    base = "sha256-O2mEquSvuKGS49cRXeUsBnHuxoNE5jO9StoXYFodZ4o=";
    luci = "sha256-qnn7+9MMAwjlot7vwUcuDl0kFOJtp/WyGELbMokVGdc=";
    packages = "sha256-MXOI+cRw7h8JXLoyG3fuFzon1bDztEjL8hI1Get740c=";
    routing = "sha256-mhmtWD/yIVFCAaE0QZUhdnppTX8AdUsQFVKYCN5/KMU=";
    telephony = "sha256-+Db5cA0XCnuBkHywpQXV54TolyjlO3SR43Ul5sDkfuA=";
  };
}
