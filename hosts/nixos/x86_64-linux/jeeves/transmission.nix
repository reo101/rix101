{ lib, pkgs, config, ... }:
{
  environment.systemPackages = with pkgs; [
    tremc
  ];

  services = {
    transmission = {
      enable = true;
      package = pkgs.transmission_4;
      openRPCPort = true;
      webHome = pkgs.flood-for-transmission;
      # TODO: `credentialsFile` for RPC password with agenix
      settings = {
        download-dir = "/data/torrents/download";
        incomplete-dir = "/data/torrents/incomplete";
        incomplete-dir-enabled = true;
        rpc-bind-address = "0.0.0.0";
        rpc-whitelist = "127.0.0.1,192.168.*.*,10.100.0.*,*.local";
      };
    };

    nginx = {
      virtualHosts."transmission.jeeves.local" = {
        enableACME = false;
        forceSSL = false;
        locations."/".proxyPass = "http://127.0.0.1:9091";
      };
    };
  };
}
