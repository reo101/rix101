{ lib, pkgs, config, ... }:
{
  environment.systemPackages = with pkgs; [
    tremc
  ];

  # networking.extraHosts = ''
  #   127.0.0.1 jeeves
  # '';

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      vaapiVdpau
      libva1
      vulkan-loader
      vulkan-validation-layers
      vulkan-extension-layer
    ];
  };

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
