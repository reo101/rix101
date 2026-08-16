# DHCP (dnsmasq + odhcpd), static leases and local DNS records.
{ lib, openwrt, secrets }:

let
  inherit (lib.custom.uci) set setRaw delete addList;

  # core dnsmasq options, same baseline on every host
  dnsmasqSettings = {
    domainneeded = "1";
    localise_queries = "1";
    rebind_protection = "1";
    rebind_localhost = "1";
    local = "/lan/";
    domain = "lan";
    expandhosts = "1";
    cachesize = "1000";
    readethers = "1";
    leasefile = "/tmp/dhcp.leases";
    resolvfile = "/tmp/resolv.conf.d/resolv.conf.auto";
    localservice = "0";
    ednspacket_max = "1232";
    confdir = "/tmp/dnsmasq.d";
    localuse = "1";
    listen_address = "127.0.0.1";
  };
in
[ "# DHCP and local DNS" ]
++ (lib.mapAttrsToList
  (key: value: set "dhcp.@dnsmasq[0].${key}" value)
  dnsmasqSettings)
# rebind domain exceptions
++ [ (delete "dhcp.@dnsmasq[0].rebind_domain") ]
++ (lib.map (domain: addList "dhcp.@dnsmasq[0].rebind_domain" domain) secrets.dnsmasqRebindDomains)
# dnsmasq address redirects (domain -> IP)
++ [ (delete "dhcp.@dnsmasq[0].address") ]
++ (lib.map
  ({ domain, ip }: addList "dhcp.@dnsmasq[0].address" "/${domain}/${ip}")
  secrets.dnsmasqAddressRedirects)
# LAN/WAN DHCP and odhcpd baseline
++ [
  (set "dhcp.lan.interface" "lan")
  (set "dhcp.lan.start" "100")
  (set "dhcp.lan.limit" "150")
  (set "dhcp.lan.leasetime" "12h")
  (set "dhcp.lan.dhcpv4" "server")
  (set "dhcp.lan.dhcpv6" "server")
  (set "dhcp.lan.ra" "server")
  (delete "dhcp.lan.ra_flags")
  (addList "dhcp.lan.ra_flags" "managed-config")
  (addList "dhcp.lan.ra_flags" "other-config")
  (delete "dhcp.lan.dhcp_option")
  (addList "dhcp.lan.dhcp_option" "6,192.168.1.1")
  (set "dhcp.wan.interface" "wan")
  (set "dhcp.wan.ignore" "1")
  (set "dhcp.odhcpd.maindhcp" "0")
  (set "dhcp.odhcpd.leasefile" "/tmp/odhcpd.leases")
  (set "dhcp.odhcpd.leasetrigger" "/usr/sbin/odhcpd-update")
  (set "dhcp.odhcpd.loglevel" "4")
  (set "dhcp.odhcpd.piodir" "/tmp/odhcpd-piodir")
  (set "dhcp.odhcpd.hostsdir" "/tmp/hosts")
  ""
]
# static leases
++ openwrt.buildNamedSectionLines {
  package = "dhcp";
  sectionType = "host";
  prefix = "host_";
  entries = secrets.staticLeases;
}
# static local DNS records (hostname -> IP)
++ (lib.concatMap
  (domainName: [
    (setRaw "dhcp.domain_${domainName}" "domain")
    (set "dhcp.domain_${domainName}.name" domainName)
    (set "dhcp.domain_${domainName}.ip" secrets.staticDomains.${domainName})
  ])
  (builtins.attrNames secrets.staticDomains))