# Minimal required metadata/hash overrides for 25.12.0 ath79/generic
let
  baseUrl = "https://downloads.openwrt.org/releases/25.12.0/targets/ath79/generic/";
  kmodsTarget = "6.12.71-1-c9318ac0cd981a67d503c47ccc54781a";
  mkSourceInfo = hash: url: { inherit hash url; };
in {
  inherit baseUrl;

  sha256sums = mkSourceInfo
    "sha256-0YWqtZCqzz0fYgxBCFhfAO+3KtfcwkA5J1YUhBs/82g="
    "${baseUrl}sha256sums";

  imagebuilder = {
    sha256 = "94df160604cacee22a5d05f2d593a23d0cef34e66ec6312ac98e0315741cbee4";
    filename = "openwrt-imagebuilder-25.12.0-ath79-generic.Linux-x86_64.tar.zst";
  };

  # Required by `nix-openwrt-imagebuilder` for profile resolution + package prefetching.
  profiles.extract = {
    kmods_target = kmodsTarget;
    default_packages = [
      "apk-mbedtls"
      "base-files"
      "ca-bundle"
      "dnsmasq"
      "dropbear"
      "firewall4"
      "fstools"
      "kmod-ath9k"
      "kmod-gpio-button-hotplug"
      "kmod-nft-offload"
      "libc"
      "libgcc"
      "libustream-mbedtls"
      "logd"
      "mtd"
      "netifd"
      "nftables"
      "odhcp6c"
      "odhcpd-ipv6only"
      "ppp"
      "ppp-mod-pppoe"
      "procd-ujail"
      "swconfig"
      "uboot-envtools"
      "uci"
      "uclient-fetch"
      "urandom-seed"
      "urngd"
      "wpad-basic-mbedtls"
    ];
    profiles.tplink_deco-m4r-v1.device_packages = [
      "kmod-ath10k-ct"
      "ath10k-firmware-qca9888-ct"
    ];
  };

  kmods.${kmodsTarget} = {
    baseUrl = "${baseUrl}kmods/${kmodsTarget}/";
    sourceInfo = mkSourceInfo
      "sha256-oJD3m1n5P7974KGlxdfOk0f+7F5P99RzS+im2kgnjtU="
      "${baseUrl}kmods/${kmodsTarget}/packages.adb";
    packages = null;
  };

  corePackages = {
    baseUrl = "${baseUrl}packages/";
    sourceInfo = mkSourceInfo
      "sha256-3EIa9QxnBGRu12/mU6nvnQL8r0+IfzVPNkF88pkZlK8="
      "${baseUrl}packages/packages.adb";
    packages = null;
  };

  packagesArch = "mips_24kc";
  feeds = import ./../../../packages/mips_24kc.nix;
}
