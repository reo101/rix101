{ inputs, lib, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
  ];

  boot.loader.grub.enable = true;

  disko = {
    enableConfig = true;
    devices = {
      disk = {
        main = {
          type = "disk";
          device = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_500GB_S2RBNX0H922939P";
          imageSize = "50G";
          content = {
            type = "gpt";
            partitions = {
              boot = {
                label = "boot_mbr";
                size = "1M";
                type = "EF02"; # BIOS boot partition for GRUB
                priority = 1;
              };
              ESP = {
                label = "boot";
                size = "512M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                };
                priority = 2;
              };
              swap = {
                label = "swap";
                size = "20G";
                content = {
                  type = "swap";
                  resumeDevice = true;
                };
                priority = 3;
              };
              nixos = {
                label = "nixos";
                size = "100%";
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                  subvolumes = {
                    # Machine-specific
                    "/root" = {
                      mountpoint = "/";
                      mountOptions = [ "compress=zstd" ];
                    };
                    "/nix" = {
                      mountpoint = "/nix";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    "/var-log" = {
                      mountpoint = "/var/log";
                      mountOptions = [ "compress=zstd" ];
                    };

                    # User
                    "/home" = {
                      mountpoint = "/home";
                      mountOptions = [ "compress=zstd" ];
                    };
                    "/persist" = {
                      mountpoint = "/persist";
                      mountOptions = [ "compress=zstd" ];
                    };
                  };
                };
                priority = 4;
              };
            };
          };
        };
      };
    };

    # NOTE: for `config.system.build.vmWithDisko`
    memSize = 2048;
    imageBuilder.copyNixStoreThreads = 8;
  };

  # zram swap (compressed in-RAM, complements disk swap)
  zramSwap.enable = true;

  # Ensure `/persist` and `/var/log` are mounted early for `impermanence` bind mounts
  fileSystems."/persist".neededForBoot = true;
  fileSystems."/var/log".neededForBoot = true;

  virtualisation.vmVariantWithDisko.virtualisation = {
    fileSystems."/persist".neededForBoot = true;
    fileSystems."/var/log".neededForBoot = true;
  };

  # Automatic `btrfs` snapshots for safe subvolumes
  services.btrbk.instances.safe = {
    onCalendar = "hourly";
    settings = {
      snapshot_preserve_min = "2d";
      snapshot_preserve = lib.concatStringsSep " " [
        "7d"
        "4w"
        "6m"
      ];

      volume."/home" = {
        snapshot_dir = ".snapshots";
        subvolume."." = { };
      };
      volume."/persist" = {
        snapshot_dir = ".snapshots";
        subvolume."." = { };
      };
    };
  };
}
