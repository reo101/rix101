# Minimal required metadata/hash overrides for 25.12.0 mediatek/filogic
let
  baseUrl = "https://downloads.openwrt.org/releases/25.12.0/targets/mediatek/filogic/";
  kmodsTarget = "6.12.71-1-60d938adcb727697d3015e4285d4c290";
  mkSourceInfo = hash: url: { inherit hash url; };
in {
  inherit baseUrl;

  sha256sums = mkSourceInfo
    "sha256-S4CWo2vMaUTNZo876OdGW7Fx9rLTiMKSgrtZjmATeC4="
    "${baseUrl}sha256sums";

  imagebuilder = {
    sha256 = "f21f651fa70b94317fa53531212136541fea03a52226ecd92c8ee900a7ff6daf";
    filename = "openwrt-imagebuilder-25.12.0-mediatek-filogic.Linux-x86_64.tar.zst";
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
      "fitblk"
      "fstools"
      "kmod-crypto-hw-safexcel"
      "kmod-gpio-button-hotplug"
      "kmod-leds-gpio"
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
      "uboot-envtools"
      "uci"
      "uclient-fetch"
      "urandom-seed"
      "urngd"
      "wpad-basic-mbedtls"
    ];
    profiles.asus_tuf-ax4200.device_packages = [
      "kmod-usb3"
      "kmod-mt7915e"
      "kmod-mt7986-firmware"
      "mt7986-wo-firmware"
    ];
  };

  kmods.${kmodsTarget} = {
    baseUrl = "${baseUrl}kmods/${kmodsTarget}/";
    sourceInfo = mkSourceInfo
      "sha256-oeMLi+52W7bnmwDVXLyoSNSfq+2CA8pe6wVg9bVY2Vk="
      "${baseUrl}kmods/${kmodsTarget}/packages.adb";
    packages = null;
  };

  corePackages = {
    baseUrl = "${baseUrl}packages/";
    sourceInfo = mkSourceInfo
      "sha256-/r3n338uGtwy9Y0l3kEgUeC6kKahhaJyeyjli6SAljA="
      "${baseUrl}packages/packages.adb";
    packages = null;
  };

  packagesArch = "aarch64_cortex-a53";
  feeds = import ./../../../packages/aarch64_cortex-a53.nix;
}
