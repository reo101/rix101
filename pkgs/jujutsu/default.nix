{ lib
, fetchFromGitHub
, rustPlatform
, jujutsu
}:

# jujutsu.overrideAttrs (finalAttrs: prevAttrs: {
#   # version = "0.27.0-dev";
#   src = fetchFromGitHub {
#     owner = "jj-vcs";
#     repo = "jj";
#     rev = "6261d576da39e5f290b064b850012bfb3c08ad5f";
#     hash = "sha256-e7/eCIu/GHjMpiOVDUCckx/EyyfIx7n+bJ/d/JX8tRo=";
#   };
#   useFetchCargoVendor = true;
#   cargoHash = "sha256-vq3gH+GGH9vhJx+1kjpy8IQdm/kTctLuyhKa4Zsqbss=";
#   cargoDepsName = finalAttrs.pname;
#   # cargoDeps = rustPlatform.fetchCargoVendor {
#   #   name = "${finalAttrs.pname}-${finalAttrs.version}-vendor.tar.gz";
#   #   inherit (finalAttrs) src;
#   #   # hash = lib.fakeHash;
#   #   hash = "sha256-0iKuQFv9bFk1I2022ysgBCQ2+9nj1EHB6v4VFlNsDxU=";
#   # };
#   cargoDeps = rustPlatform.fetchCargoVendor {
#     inherit (finalAttrs) pname src version;
#     hash = finalAttrs.cargoHash;
#   };
# })

jujutsu.override (old: {
  rustPlatform = old.rustPlatform // {
    buildRustPackage = args: old.rustPlatform.buildRustPackage (args // {
      version = "0.27.0-dev";

      src = fetchFromGitHub {
        owner = "jj-vcs";
        repo = "jj";
        rev = "6261d576da39e5f290b064b850012bfb3c08ad5f";
        hash = "sha256-e7/eCIu/GHjMpiOVDUCckx/EyyfIx7n+bJ/d/JX8tRo=";
      };

      cargoHash = "sha256-rnVz7qkgnkGvXt5ENaXdI8EtLoya49WYHnfyKbkZoLM";
    });
  };
})
