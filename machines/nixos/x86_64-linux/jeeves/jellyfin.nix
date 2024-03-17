{ lib, pkgs, config, ... }:
{
  environment.systemPackages = with pkgs; [
    tremc
  ];

  networking.extraHosts = ''
    127.0.0.1 jeeves
  '';

  hardware.opengl.extraPackages = with pkgs; [
    vaapiVdpau
    libva1
  ];

  services = {
    transmission = {
      enable = true;
      openRPCPort = true;
      # TODO: `credentialsFile` for RPC password with agenix
      settings = {
        download-dir = "/data/torrents/download";
        incomplete-dir = "/data/torrents/incomplete";
        incomplete-dir-enabled = true;
        rpc-bind-address = "0.0.0.0";
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
