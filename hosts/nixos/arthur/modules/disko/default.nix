{
  inputs,
  ...
}:

let
  filesystem = "btrfs"; # "btrfs" or "zfs"
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

  # zram swap (compressed in-RAM, complements disk swap)
  zramSwap.enable = true;

  # Ensure `/persist` and `/var/log` are mounted early for `impermanence` bind mounts
  fileSystems."/persist".neededForBoot = true;
  fileSystems."/var/log".neededForBoot = true;
}
