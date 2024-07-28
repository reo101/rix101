{ inputs, lib, pkgs, config, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
  ];

  environment.systemPackages = with pkgs; [
    # `statfs` for btrfs commands
    gocryptfs
  ];

  # If on installer
  disko.enableConfig = true;

  # `head -c 8 /etc/machine-id`
  networking.hostId = "1418566e";

  # NOTE: needed for mounting `/key` (for LUKS)
  boot.initrd.kernelModules = [
    "uas"
    "ext4"
  ];

  # HACK: for troubleshooting
  # see https://github.com/NixOS/nixpkgs/blob/9d6655c6222211adada5eeec4a91cb255b50dcb6/nixos/modules/system/boot/stage-1-init.sh#L45-L49
  boot.initrd.preFailCommands = ''
    export allowShell=1
  '';

  # NOTE: doesn't get mounted early enough, see below
  # fileSystems."/key" = {
  #   device = "/dev/disk/by-partlabel/key";
  #   fsType = "ext4";
  #   neededForBoot = true;
  # };

  disko = {
    devices = {
      disk = {
        # NOTE: we could do this to setup a usb for the keys
        #       but disko overrides it with no option of ignoring when partitioning
        #       (i.e. tell disko to only use this only for decalartion)
        # key = {
        #   type = "disk";
        #   device = "/dev/disk/by-id/usb-USB2.0_Flash_Disk_1000000000001D8B-0";
        #   content = {
        #     type = "gpt";
        #     partitions = {
        #       key = {
        #         label = "key";
        #         size = "100%";
        #         content = {
        #           type = "filesystem";
        #           format = "ext4";
        #           mountpoint = "/key";
        #         };
        #       };
        #     };
        #   };
        # };
        ssd1 = {
          type = "disk";
          device = "/dev/disk/by-id/nvme-eui.e8238fa6bf530001001b448b4ebde3a6";
          content = {
            type = "gpt";
            partitions = {
              boot = {
                label = "boot_mbr";
                size = "1M";
                type = "EF02"; # for grub MBR
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
              root = {
                label = "root";
                size = "100%";
                content = {
                  type = "luks";
                  name = "root";
                  extraOpenArgs = [ ];
                  settings = {
                    keyFile = "/key/root";
                    # HACK: we need to manually wait for and mount the partition containing the keys
                    preOpenCommands = ''
                      # Prepare (kernel modules and directory for mounting)
                      modprobe uas
                      modprobe ext4
                      mkdir -m "0755" -p "/key"

                      # Loop until mounted (+ initial wait)
                      sleep 5
                      until mount -n -t "ext4" -o "ro" "/dev/disk/by-partlabel/key" "/key" 2>&1 1>/dev/null; do
                        echo 'Could not find a partition with label `key` (at `/dev/disk/by-partlabel/key`), retrying...'
                        sleep 2
                      done
                    '';
                  };
                  content = {
                    type = "btrfs";
                    extraArgs = [ "-f" ]; # Override existing partition
                    subvolumes = {
                      "/root" = {
                        mountpoint = "/";
                      };
                    };
                  };
                };
                priority = 3;
              };
            };
          };
        };
        hdd1 = {
          type = "disk";
          device = "/dev/disk/by-id/ata-WDC_WD8003FFBX-68B9AN0_VYJB5TUM";
          content = {
            type = "gpt";
            partitions = {
              mdadm = {
                label = "hdd1";
                size = "100%";
                content = {
                  type = "mdraid";
                  name = "tank";
                };
              };
            };
          };
        };
        hdd2 = {
          type = "disk";
          device = "/dev/disk/by-id/ata-WDC_WD8003FFBX-68B9AN0_VYHZTWSM";
          content = {
            type = "gpt";
            partitions = {
              mdadm = {
                label = "hdd2";
                size = "100%";
                content = {
                  type = "mdraid";
                  name = "tank";
                };
              };
            };
          };
        };
      };
      mdadm = {
        tank = {
          type = "mdadm";
          level = 1;
          content = {
            type = "luks";
            name = "tank";
            extraOpenArgs = [ "--allow-discards" ];
            settings.keyFile = "/key/tank";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ]; # Override existing partition
              subvolumes = {
                "/home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "compress=zstd"
                  ];
                };
                "/nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "/data" = {
                  mountpoint = "/data";
                  mountOptions = [
                    "compress=zstd"
                  ];
                };
                "/data/media" = { };
                "/data/torrents" = { };
                "/data/torrents/download" = { };
                "/data/torrents/incomplete" = { };
                "/data/media/jellyfin" = { };
                "/data/samba" = { };
                "/data/samba/private" = { };
                "/data/samba/public" = { };
              };
            };
          };
        };
      };
    };
  };
}
