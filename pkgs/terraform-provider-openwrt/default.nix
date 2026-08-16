# Foxboron/terraform-provider-openwrt — built from source with a local fork.
#
# Upstream cellared the release as a plain binary, but 25.12 doesn't ship a
# working opkg (see skip-opkg-refresh.patch), so we build the v0.2.0 source
# here with `doCheck = false` (the upstream test suite needs mockgen output
# that isn't vendored) and carry one patch: demote the configure-time
# package-list refresh to a warning, since we only manage openwrt_configfile.
# The provider is consumed as a filesystem mirror by the openwrt-tofu apps.
#
# To bump: change `version`, the `src` URL/hash and the patch together.
{
  lib,
  fetchFromGitHub,
  buildGoModule,
}:

let
  version = "0.2.0";
in
buildGoModule (finalAttrs: {
  pname = "terraform-provider-openwrt";
  inherit version;

  src = fetchFromGitHub {
    owner = "Foxboron";
    repo = "terraform-provider-openwrt";
    rev = "v${version}";
    hash = "sha256-wjswfQVMxdfjhXR49z+I7nEaUkeCrW/MKjvYr/NKfrI=";
  };

  patches = [
    ./skip-opkg-refresh.patch
  ];

  # Upstream `*_test.go` import an uncommitted mockgen package
  # (`internal/mocks`), which breaks `go mod vendor`; `internal/testutil`
  # and the `tools/` module are unneeded for the provider build.
  postUnpack = ''
    rm -rf "$sourceRoot"/internal/resources/opkg/opkg_test.go \
           "$sourceRoot"/internal/resources/service/service_test.go \
           "$sourceRoot"/internal/testutil \
           "$sourceRoot"/tools
  '';

  doCheck = false;
  vendorHash = "sha256-GM5TDAbHH4ZxIxbP48SIUpb+i5eGvmbz+ImTqOd0GVk=";

  meta = {
    description = "OpenTofu/Terraform provider for OpenWrt (LuCI-RPC transport)";
    homepage = "https://github.com/Foxboron/terraform-provider-openwrt";
    license = lib.licenses.mpl20;
    platforms = lib.platforms.linux;
    mainProgram = "terraform-provider-openwrt";
  };
})
