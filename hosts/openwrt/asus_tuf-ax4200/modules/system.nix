# Public system, NTP, dropbear, and uhttpd baseline. Additional dropbear values
# are merged from the encrypted runtime router document.
{ lib, ... }:

let
  inherit (lib.custom.uci) set delete addList;
  systemSettings = {
    hostname = "OpenWrt";
    timezone = "EET-2EEST,M3.5.0/3,M10.5.0/4";
    zonename = "Europe/Sofia";
    log_proto = "udp";
    conloglevel = "8";
    cronloglevel = "5";
  };
  ntpServers = map (n: "${toString n}.openwrt.pool.ntp.org") (lib.range 0 3);
  # Shared hardening baseline; secret-bearing extras merge at runtime.
  dropbearBaseline = {
    PasswordAuth = "off";
    RootPasswordAuth = "off";
  };
  sections = [
    {
      id = "system";
      config = "system";
      type = "system";
      match = { };
      authoritative = false;
      options = systemSettings;
      lists = { };
    }
    {
      id = "ntp";
      config = "system";
      type = "timeserver";
      name = "ntp";
      authoritative = false;
      options = { };
      lists.server = ntpServers;
    }
    {
      id = "dropbear";
      config = "dropbear";
      type = "dropbear";
      match = { };
      authoritative = false;
      options = dropbearBaseline;
      lists = { };
    }
    {
      id = "uhttpd_main";
      config = "uhttpd";
      type = "uhttpd";
      name = "main";
      authoritative = false;
      options.redirect_https = "0";
      lists = { };
    }
  ];
  opLines =
    lib.mapAttrsToList (key: value: set "system.@system[0].${key}" value) systemSettings
    ++ [ (delete "system.ntp.server") ]
    ++ map (server: addList "system.ntp.server" server) ntpServers
    ++ lib.mapAttrsToList (key: value: set "dropbear.@dropbear[0].${key}" value) dropbearBaseline
    ++ [ (set "uhttpd.main.redirect_https" "0") ];
in
{
  inherit opLines sections;
}
