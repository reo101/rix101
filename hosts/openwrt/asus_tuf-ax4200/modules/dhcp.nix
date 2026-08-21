# Public DHCP/dnsmasq baseline. Static leases, local domains, and private
# dnsmasq exceptions live in the encrypted runtime router document.
{ lib, ... }:

let
  inherit (lib.custom.uci) set delete addList;

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
  };
  lanSettings = {
    interface = "lan";
    start = "100";
    limit = "150";
    leasetime = "12h";
    dhcpv4 = "server";
    dhcpv6 = "server";
    ra = "server";
  };
  wanSettings = {
    interface = "wan";
    ignore = "1";
  };
  odhcpdSettings = {
    maindhcp = "0";
    leasefile = "/tmp/odhcpd.leases";
    leasetrigger = "/usr/sbin/odhcpd-update";
    loglevel = "4";
    piodir = "/tmp/odhcpd-piodir";
    hostsdir = "/tmp/hosts";
  };

  sections = [
    {
      id = "dnsmasq";
      config = "dhcp";
      type = "dnsmasq";
      match = { };
      authoritative = false;
      options = dnsmasqSettings;
      lists = { };
    }
    {
      id = "lan";
      config = "dhcp";
      type = "dhcp";
      name = "lan";
      authoritative = true;
      options = lanSettings;
      lists = {
        ra_flags = [ "managed-config" "other-config" ];
        dhcp_option = [ "6,192.168.1.1" ];
      };
    }
    {
      id = "wan";
      config = "dhcp";
      type = "dhcp";
      name = "wan";
      authoritative = true;
      options = wanSettings;
      lists = { };
    }
    {
      id = "odhcpd";
      config = "dhcp";
      type = "odhcpd";
      name = "odhcpd";
      authoritative = true;
      options = odhcpdSettings;
      lists = { };
    }
  ];

  opLines =
    [ "# Public DHCP bootstrap" ]
    ++ lib.mapAttrsToList (key: value: set "dhcp.@dnsmasq[0].${key}" value) dnsmasqSettings
    ++ lib.mapAttrsToList (key: value: set "dhcp.lan.${key}" value) lanSettings
    ++ [
      (delete "dhcp.lan.ra_flags")
      (addList "dhcp.lan.ra_flags" "managed-config")
      (addList "dhcp.lan.ra_flags" "other-config")
      (delete "dhcp.lan.dhcp_option")
      (addList "dhcp.lan.dhcp_option" "6,192.168.1.1")
    ]
    ++ lib.mapAttrsToList (key: value: set "dhcp.wan.${key}" value) wanSettings
    ++ lib.mapAttrsToList (key: value: set "dhcp.odhcpd.${key}" value) odhcpdSettings;
in
{
  inherit opLines sections;
}
