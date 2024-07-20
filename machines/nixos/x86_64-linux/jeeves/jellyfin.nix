{ lib, pkgs, config, ... }:
{
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
    nginx = {
      virtualHosts."jellyfin.jeeves.local" = {
        enableACME = false;
        forceSSL = false;
        locations."/".proxyPass = "http://127.0.0.1:8096";
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
