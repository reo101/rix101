{ config, nixpkgs, ... }:

### Jellyfin
# nixpkgs.config.packageOverrides = pkgs: {
#   arc = import (builtins.fetchTarball {
#     url = "https://github.com/arcnmx/nixexprs/archive/1a2ca1935e243383dfc8dc89f88f55678d33fcd4.tar.gz";
#     sha256 = "sha256:0zjy3916sxxk7ds763dmmbzfdc46wdlw10m5dg6kkpqi2i81109f";
#   }) {
#     inherit pkgs;
#   };
#   vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
# };

# hardware.nvidia.package = pkgs.arc.packages.nvidia-patch.override {
#   nvidia_x11 = config.boot.kernelPackages.nvidiaPackages.stable;
# };

# hardware.opengl = {
#   enable = true;
#   extraPackages = with pkgs; [
#     intel-media-driver
#     vaapiIntel
#     vaapiVdpau
#     libvdpau-va-gl
#     intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
#   ];
# };

virtualisation.oci-containers.containers."jellyfin" = {
  autoStart = true;
  image = "docker.io/jellyfin/jellyfin:latest";
  volumes = [
    "/var/cache/jellyfin/config:/config"
    "/var/cache/jellyfin/cache:/cache"
    "/var/log/jellyfin:/log"
    "/media:/media:ro"
  ];
  ports = [ "8096:8096" ];
  environment = {
    JELLYFIN_LOG_DIR = "/log";
  };
};

## services.jellyfin.enable = true;

## systemd.services."jellyfin".serviceConfig = {
##   DeviceAllow = pkgs.lib.mkForce [
##     "char-drm rw"
##     "char-nvidia-frontend rw"
##     "char-nvidia-uvm rw"
##   ];
##   PrivateDevices = pkgs.lib.mkForce true;
##   RestrictAddressFamilies = pkgs.lib.mkForce [
##     "AF_UNIX"
##     "AF_NETLINK"
##     "AF_INET"
##     "AF_INET6"
##   ];
## };

