{ lib, fetchFromGitHub, buildGoModule, ... }:

buildGoModule rec {
  pname = "cy";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "cfoust";
    repo = "${pname}";
    rev = "v${version}";
    hash = "sha256-05yld6cU0P+0u9BvZ873APATN74AmwT6Uu1/GVL9y9U=";
  };

  vendorHash = null;

  doCheck = false;
}
