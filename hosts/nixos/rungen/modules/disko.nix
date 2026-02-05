{
  inputs,
  lib,
  config,
  ...
}:
let
  disk = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S7HENJ0Y333620Z";

  mkDataset =
    mountpoint:
    {
      snapshot ? false,
      refreservation ? null,
      extraOptions ? { },
    }:
    {
      type = "zfs_fs";
      inherit mountpoint;
      options = {
        "com.sun:auto-snapshot" = lib.boolToString snapshot;
        canmount = "on";
        mountpoint = "legacy";
      }
      // lib.optionalAttrs (refreservation != null) {
        inherit refreservation;
      }
      // extraOptions;
    };
in
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.disko-zfs.nixosModules.default
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = lib.mkDefault true;
    grub.enable = false;
  };

  # `head -c 8 /etc/machine-id` (required for ZFS)
  networking.hostId = "a8997eee";

  disko = {
    enableConfig = true;
    devices = {
      disk.main = {
        type = "disk";
        device = disk;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              device = "${disk}-part1";
              priority = 0;
              size = "4G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            zfs = {
              device = "${disk}-part2";
              priority = 1;
              end = "-96G";
              type = "BF00";
              content = {
                type = "zfs";
                pool = "zfs_root";
              };
            };
            swap = {
              device = "${disk}-part3";
              priority = 2;
              size = "96G";
              content = {
                type = "swap";
                randomEncryption = false;
              };
            };
          };
        };
      };

      zpool.zfs_root = {
        type = "zpool";
        mode = "";
        options = {
          autotrim = "on";
          listsnapshots = "on";
        };
        rootFsOptions = {
          acltype = "posixacl";
          atime = "off";
          canmount = "off";
          checksum = "sha512";
          compression = "lz4";
          xattr = "sa";
          mountpoint = "none";
          "com.sun:auto-snapshot" = "false";
        };

        postCreateHook = "zfs snapshot zfs_root@blank";

        datasets = {
          "root" = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {
              "com.sun:auto-snapshot" = "false";
              mountpoint = "legacy";
            };
          };
          "root/nix" = mkDataset "/nix" {
            refreservation = "100GiB";
            extraOptions.compression = "off";
          };
          "root/var" = mkDataset "/var" {
            snapshot = true;
          };
          "root/var/lib" = mkDataset "/var/lib" {
            snapshot = true;
          };
          "root/home" = mkDataset "/home" {
            snapshot = true;
            refreservation = "200GiB";
          };
          "root/var/lib/docker" = mkDataset "/var/lib/docker" {
            refreservation = "100GiB";
          };
          "root/var/lib/containers" = mkDataset "/var/lib/containers" {
            refreservation = "100GiB";
          };
        };
      };
    };
  };

  services.zfs.autoSnapshot.enable = true;

  disko.zfs = {
    enable = true;
    settings.logLevel = "info";
  };
}
