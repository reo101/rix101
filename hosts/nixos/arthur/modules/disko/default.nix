{
  inputs,
  ...
}:

let
  # NOTE: "btrfs" or "zfs"
  filesystem = "zfs";
in
{
  imports = [
    inputs.disko.nixosModules.disko
    ./${filesystem}.nix
  ];

  disko = {
    enableConfig = true;
    devices.disk.main = {
      type = "disk";
      device = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_500GB_S2RBNX0H922939P";
      imageSize = "50G";
    };
  };

  # `zram` swap (compresses swap in RAM)
  zramSwap.enable = true;

  # Ensure `/persist` is mounted early for `impermanence` bind mounts
  fileSystems."/persist".neededForBoot = true;
}
