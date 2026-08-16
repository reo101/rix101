# ASUS TUF-AX4200 — OpenWrt 25.12.0 (mediatek/filogic)
#
# Built with nix-openwrt-imagebuilder: packages + first-boot uci-defaults
# generated from the section modules below. Config is authored per-section;
# site values (WAN/LAN addressing, WiFi, leases, redirects) come from the
# age-encrypted `secrets.nix.age`.
{ lib, pkgs }:

let
  openwrt = lib.custom.openwrt pkgs;

  secrets = lib.custom.rageImportEncrypted ./secrets.nix.age;

  section = name: import ./modules/${name}.nix { inherit lib openwrt secrets; };

  uciBatchLines = lib.concatLists [
    (section "network")
    (section "wireless")
    (section "dhcp")
    (section "firewall")
    (section "system")
  ];
in
{
  packages = openwrt.defaultPackages;

  files = openwrt.mkImageFiles {
    uciBatchLines = uciBatchLines
      ++ [ "" ]
      ++ openwrt.commitLines [
        "network"
        "wireless"
        "dhcp"
        "firewall"
        "system"
        "dropbear"
        "uhttpd"
      ];
  };
}