# Deco M4R AP #2 (192.168.1.3) — same hardware/role as `deco_m4r_v2`.
{ lib, pkgs, ... }:

import ../../modules/openwrt/deco.nix {
  inherit lib pkgs;
  ip = "192.168.1.3";
  hostname = "deco-m4r-2";
  extraImageName = "deco-m4r-b-ap";
}