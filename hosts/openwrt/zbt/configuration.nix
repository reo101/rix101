# ZBT WR-8305RT — OpenWrt 22.03.7 (ramips/mt7620) — minimal test AP.
{ lib, pkgs }:

let
  inherit (lib.custom) uci;

  openwrt = lib.custom.openwrt pkgs;
in
{
  # bump image so updates don't collide with previous installs
  packages = [ "tcpdump" ];

  disabledServices = [ "dnsmasq" ];

  files = openwrt.mkImageFiles {
    uciBatchLines = [
      "# Test AP"
      (uci.set "system.@system[0].hostname" "testap")
      ""
    ] ++ openwrt.commitLines [ "system" ];
  };
}