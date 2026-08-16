# Shared configuration for the two Deco M4R access points.
#
# Each host's `configuration.nix` is just this applied with its own
# `ip` / `hostname` / `extraImageName`. Everything else (AP defaults,
# dropbear lockdown, https redirect) lives here exactly once.
{
  lib,
  pkgs,
  ip,
  hostname,
  extraImageName ? "deco-m4r-ap",
}:

let
  inherit (lib.custom) uci;

  openwrt = lib.custom.openwrt pkgs;

  uciBatchLines = [
    "# AP defaults"
    (uci.delete "dhcp.wan")
    (uci.set "dhcp.lan.ignore" "1")
    (uci.set "network.lan.ipaddr" ip)
    (uci.set "network.lan.gateway" "192.168.1.1")
    (uci.delete "network.lan.dns")
    (uci.addList "network.lan.dns" "192.168.1.1")
    (uci.set "system.@system[0].hostname" hostname)
    (uci.set "system.@system[0].zonename" "Europe/Sofia")
    (uci.set "system.@system[0].timezone" "EET-2EEST,M3.5.0/3,M10.5.0/4")
    (uci.set "dropbear.@dropbear[0].PasswordAuth" "off")
    (uci.set "dropbear.@dropbear[0].RootPasswordAuth" "off")
    (uci.set "uhttpd.main.redirect_https" "1")
    ""
  ] ++ openwrt.commitLines [
    "network"
    "dhcp"
    "system"
    "dropbear"
    "uhttpd"
  ];
in
{
  inherit extraImageName;

  packages = openwrt.defaultPackages ++ [
    "iperf3"
    "luci-app-advanced-reboot"
  ];

  files = openwrt.mkImageFiles { inherit uciBatchLines; };
}