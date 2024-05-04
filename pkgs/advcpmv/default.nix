{ stdenv, fetchurl, fetchpatch }:

let
  advcpmv_owner = "jarun";
  advcpmv_version = "0.9";
  coreutils_version = "9.1";
  coreutils_upstream = "coreutils";
  patch_rev = "1e2b1c6b74fa0974896bf94604279a3f74b37a63";
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
      hash = "sha256-d+SRT/R4xmfHLAdOr7m4R3WFiW64P5ZH6iqDvErYCyg=";
    })
  ];

  installPhase = ''
    install -D "src/cp" "$out/bin/advcp"
    install -D "src/mv" "$out/bin/advmv"
  '';
}
