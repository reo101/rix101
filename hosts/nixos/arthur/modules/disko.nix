{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = [
    inputs.disko.nixosModules.disko
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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
              ESP = {
                label = "ESP";
                size = "512M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                };
                priority = 1;
              };
              swap = {
                label = "swap";
                size = "20G";
                content = {
                  type = "swap";
                  resumeDevice = true;
                };
                priority = 2;
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
                priority = 3;
              };
            };
          };
        };
      };
    };
  };

  # zram swap (compressed in-RAM, complements disk swap)
  zramSwap.enable = true;

  # Ensure `/persist` and `/var/log` are mounted early for `impermanence` bind mounts
  fileSystems."/persist".neededForBoot = true;
  fileSystems."/var/log".neededForBoot = true;

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
