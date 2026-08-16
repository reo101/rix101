# L2/L3 topology for the ASUS TUF-AX4200
#
# Everything LAN/WAN/wwan/wan6 + the ULA prefix. Bridge member ports
# are hardware facts; addresses/DNS come from secrets.
{ lib, secrets }:

let
  inherit (lib.custom.uci) set setRaw delete addList;
  lanPorts = [ "lan1" "lan2" "lan3" "lan4" ];
in
[
  "# Network"
  (delete "network.@device[0].ports")
]
++ (lib.map (port: addList "network.@device[0].ports" port) lanPorts)
# LAN settings (device/addresses from secrets)
++ (lib.mapAttrsToList
  (key: value: set "network.lan.${key}" value)
  secrets.lanSettings)
# Reset IPv6 class list before custom values
++ [
  (delete "network.lan.ip6class")
]
++ (lib.map (ip6class: addList "network.lan.ip6class" ip6class) secrets.lanIp6Classes)
# WAN settings except DNS (handled as a list below)
++ (lib.mapAttrsToList
  (key: value: set "network.wan.${key}" value)
  (lib.removeAttrs secrets.wanSettings [ "dns" ]))
# WAN DNS resolvers
++ [
  (delete "network.wan.dns")
]
++ (lib.map (dns: addList "network.wan.dns" dns) secrets.wanSettings.dns)
# Fallback WWAN (cellular/sta) and WAN6 (DHCPv6-PD)
++ [
  (setRaw "network.wwan" "interface")
  (set "network.wwan.proto" "dhcp")
  (set "network.wwan.metric" "20")
  (set "network.wwan.auto" "1")
  (setRaw "network.wan6" "interface")
  (set "network.wan6.proto" "dhcpv6")
  (set "network.wan6.device" "@wan")
  (set "network.wan6.reqaddress" "try")
  (set "network.wan6.reqprefix" "auto")
  # published ULA prefix (site-local, not secret)
  (set "network.globals.ula_prefix" "fdfd:6384:e4b9::/48")
]