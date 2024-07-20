{ inputs, outputs, lib, pkgs, config, ... }:

{
  environment.systemPackages = [
    # config.services.nextcloud.package
  ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx = {
    enable = true;
    package = pkgs.openresty;
    # virtualHosts."_.jeeves.local" = {
    #   # listen = [
    #   #   {
    #   #     addr = "127.0.0.1";
    #   #     port = 1234;
    #   #   }
    #   # ];
    #   enableACME = false;
    #   forceSSL = false;
    #   locations."/".proxyPass = "http://127.0.0.1:1234";
    # };
  };
}
