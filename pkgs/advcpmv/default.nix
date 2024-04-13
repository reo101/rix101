{ stdenv, fetchurl, fetchpatch }:

let
  advcpmv_owner = "jarun";
  advcpmv_version = "0.9";
  coreutils_version = "9.1";
  coreutils_upstream = "coreutils";
  patch_rev = "69d2f9d3c72ec149fc7e06f5154af27db857ebb5";
in
stdenv.mkDerivation rec {
  name = "advcpmv";
  version = advcpmv_version;

  src = fetchurl {
    name = "source-${name}-${coreutils_version}.tar.xz";
    url = "ftp://ftp.gnu.org/gnu/${coreutils_upstream}/${coreutils_upstream}-${coreutils_version}.tar.xz";
    sha256 = "sha256-YaH0ENeLp+fzelpPUObRMgrKMzdUhKMlXt3xejhYBCM=";
  };

  patches = [
    (fetchpatch {
      url = "https://raw.githubusercontent.com/${advcpmv_owner}/${name}/${patch_rev}/${name}-${advcpmv_version}-${coreutils_version}.patch";
      hash = "sha256-l7kf2vz/heW3lgT89yDs5Wdfzw3Xbb3QhPGct7SCruQ=";
    })
  ];

  installPhase = ''
    install -D "src/cp" "$out/bin/advcp"
    install -D "src/mv" "$out/bin/advmv"
  '';
}
