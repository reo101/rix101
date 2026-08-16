# System, NTP, dropbear hardening, uhttpd.
{ lib, openwrt, secrets }:

openwrt.baselineLines {
  hostname = "OpenWrt";
  redirect_https = "0"; # LAN-only LuCI over HTTP
}
++ [
  "# SSH (dropbear)"
]
++ openwrt.dropbearLines (
  secrets.dropbearConfig // openwrt.dropbearBaseline
)