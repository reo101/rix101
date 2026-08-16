# Deco M4R AP #1 (192.168.1.2). Shared AP config lives in
# `modules/openwrt/deco.nix`; only per-host bits (IP/hostname) here.
{ lib, pkgs, ... }:

import ../../modules/openwrt/deco.nix {
  inherit lib pkgs;
  ip = "192.168.1.2";
  hostname = "deco-m4r-1";
}