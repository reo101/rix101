{ pkgs, ... }:
{
  # NVIDIA NVS 4200M (Fermi/GF108) via nouveau
  # Proprietary 390.xx driver is broken on kernel 6.18+
  services.xserver.videoDrivers = [
    "modesetting"
    "nouveau"
  ];

  hardware.graphics = {
    enable = true;
    extraPackages = [
      # VA-API for Sandy Bridge (pre-Broadwell)
      pkgs.intel-vaapi-driver
      # VDPAU-to-VA-API bridge
      pkgs.libvdpau-va-gl
    ];
  };

  # DRI_PRIME=1 can be used to offload rendering to the NVS 4200M
}
