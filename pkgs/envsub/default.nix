{ lib, fetchFromGitHub, rustPlatform, ... }:

rustPlatform.buildRustPackage rec {
  pname = "envsub";
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "stephenc";
    repo = pname;
    tag = "v${version}";
    hash = "sha256-DYfGH/TnDTaG5799upg4HDNFiMYpkE64s2DNXJ+1NnE=";
  };

  cargoHash = "sha256-1b0nhfbk7g2XiplOeVB25VQV2E3Z7B9tqANYvhOO6AQ=";

  meta = with lib; {
    description = "zkSnark circuit compiler";
    homepage = "https://github.com/stephenc/envsub";
    maintainers = with maintainers; [ reo101 ];
  };
}
