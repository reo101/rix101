# ASUS TUF-AX4200 — OpenWrt 25.12.0 (mediatek/filogic)
#
# The image contains packages, SSH bootstrap, and public UCI defaults only.
# Secret-bearing site configuration is decrypted at runtime by nixops4-openwrt.
{ lib, pkgs }:

let
  openwrt = lib.custom.openwrt pkgs;
  section = name: import ./modules/${name}.nix { inherit lib openwrt; };
  modules = map section [
    "network"
    "wireless"
    "dhcp"
    "firewall"
    "system"
  ];
  uciBatchLines = lib.concatMap (module: module.opLines or [ ]) modules;
in
{
  packages = openwrt.defaultPackages;

  files = openwrt.mkImageFiles {
    uciBatchLines = uciBatchLines
      ++ [ "" ]
      ++ openwrt.commitLines [
        "network"
        "dhcp"
        "system"
        "dropbear"
        "uhttpd"
      ];
  };
}
