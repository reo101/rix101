# Firewall: WAN zone member networks + port-forward redirects.
# The rule set itself (Allow-Ping, ICMPv6, ...) ships with the base image.
{ lib, openwrt, secrets }:

let
  inherit (lib.custom.uci) delete addList;
in
[
  "# Firewall: keep wwan in WAN zone, and restore forwards"
  (delete "firewall.@zone[1].network")
]
++ (lib.map (network: addList "firewall.@zone[1].network" network) secrets.firewallWanNetworks)
++ openwrt.buildNamedSectionLines {
  package = "firewall";
  sectionType = "redirect";
  prefix = "redirect_";
  entries = secrets.firewallRedirects;
}