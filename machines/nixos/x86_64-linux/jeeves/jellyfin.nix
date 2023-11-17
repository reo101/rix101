{ lib, pkgs, config, ... }:
{
  environment.systemPackages = with pkgs; [
    tremc
  ];

  services = {
    transmission = {
      enable = true;
      openRPCPort = true;
      settings = {
        download-dir = "/data/torrents/download";
        incomplete-dir = "/data/torrents/incomplete";
        incomplete-dir-enabled = true;
        rpc-whitelist = "127.0.0.1,192.168.*.*,10.100.0.*";
      };
    };
    jellyfin = {
      enable = true;
      openFirewall = true;
    };
    # sonarr = {
    #   enable = true;
    #   openFirewall = true;
    # };
    # radarr = {
    #   enable = true;
    #   openFirewall = true;
    # };
    # bazarr = {
    #   enable = true;
    #   openFirewall = true;
    # };
    # readarr = {
    #   enable = true;
    #   openFirewall = true;
    # };
    # prowlarr = {
    #   enable = true;
    #   openFirewall = true;
    # };
  };
}
