# Public L2/L3 topology. Site addresses and resolvers come from the encrypted
# runtime configuration consumed by nixops4-openwrt.
{ lib, ... }:

let
  inherit (lib.custom.uci) set setRaw delete addList;
  lanPorts = [ "lan1" "lan2" "lan3" "lan4" ];

  sections = [
    {
      id = "lan_bridge";
      config = "network";
      type = "device";
      match = { name = "br-lan"; };
      authoritative = false;
      options = { };
      lists.ports = lanPorts;
    }
    # Bridge attachment lives here; addresses come from the runtime secret
    # fragment with the same id.
    {
      id = "lan";
      config = "network";
      type = "interface";
      name = "lan";
      authoritative = true;
      options.device = "br-lan";
      lists = { };
    }
    {
      id = "wwan";
      config = "network";
      type = "interface";
      name = "wwan";
      authoritative = true;
      options = {
        proto = "dhcp";
        metric = "20";
        auto = "1";
      };
      lists = { };
    }
    {
      id = "wan6";
      config = "network";
      type = "interface";
      name = "wan6";
      authoritative = true;
      options = {
        proto = "dhcpv6";
        device = "@wan";
        reqaddress = "try";
        reqprefix = "auto";
      };
      lists = { };
    }
    {
      id = "globals";
      config = "network";
      type = "globals";
      name = "globals";
      authoritative = false;
      options.ula_prefix = "fdfd:6384:e4b9::/48";
      lists = { };
    }
  ];

  opLines = [
    "# Public network bootstrap"
    (delete "network.@device[0].ports")
  ]
  ++ map (port: addList "network.@device[0].ports" port) lanPorts
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
    (set "network.globals.ula_prefix" "fdfd:6384:e4b9::/48")
  ];
in
{
  inherit opLines sections;
}
