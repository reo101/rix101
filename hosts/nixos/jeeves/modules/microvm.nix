{ inputs, lib, pkgs, config, ... }:

let
  microvm-interface = "microvm";
  microvm-network-cidr = "10.0.0.0/24";
  microvm-network-host-cidr = lib.net.cidr.hostCidr 1 microvm-network-cidr;
  microvm-network-gateway = lib.net.cidr.host 1 microvm-network-cidr;
in
{
  imports = [
    inputs.microvm.nixosModules.host
  ];

  # MicroVM host configuration
  microvm.host.enable = true;

  # Bridge for MicroVM networking
  systemd.network = {
    netdevs."50-${microvm-interface}" = {
      netdevConfig = {
        Kind = "bridge";
        Name = microvm-interface;
      };
    };
    networks."50-${microvm-interface}" = {
      matchConfig.Name = microvm-interface;
      addresses = [
        { Address = microvm-network-host-cidr; }
      ];
      networkConfig = {
        DHCPServer = true;
        IPv6SendRA = true;
      };
      linkConfig.RequiredForOnline = "no";
    };
    networks."51-${microvm-interface}-vm" = {
      matchConfig.Driver = "tun";
      matchConfig.Name = "vm-*";
      networkConfig.Bridge = microvm-interface;
      linkConfig.RequiredForOnline = "enslaved";
    };
  };

  # NAT for microvm network
  networking.nat = {
    enable = true;
    internalInterfaces = [ microvm-interface ];
  };

  # Allow DHCP and DNS on the bridge
  networking.firewall.interfaces.${microvm-interface} = {
    allowedTCPPorts = [ 22 ];
    allowedUDPPorts = [ 53 67 ];
  };
}
