{ inputs, lib, pkgs, utils, ... }:
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

  # HACK: `mdadm: No mail address or alert command - not monitoring.`
  boot.swraid.mdadmConf = "MAILADDR root";

  # HACK: for troubleshooting
  boot.initrd.systemd.emergencyAccess = true;

  # LUKS key files live on a separate USB/ext4 partition. In systemd stage 1,
  # mount the USB, copy the keys into initrd tmpfs, then let cryptsetup use the
  # tmpfs copies. This avoids cryptsetup depending on /key, so /key can be
  # unmounted before switch-root and the USB can be removed after boot.
  boot.initrd.systemd.mounts = [
    {
      description = "Mount LUKS key partition";
      what = "/dev/disk/by-partlabel/key";
      where = "/key";
      type = "ext4";
      options = "ro";
      wantedBy = [ "copy-luks-keys.service" ];
      before = [
        "copy-luks-keys.service"
        "initrd-switch-root.target"
        "shutdown.target"
      ];
      wants = [ "systemd-udev-trigger.service" ];
      after = [
        "systemd-modules-load.service"
        "systemd-udev-trigger.service"
      ];
      conflicts = [
        "initrd-switch-root.target"
        "shutdown.target"
      ];
      unitConfig.DefaultDependencies = "no";
    }
  ];

  boot.initrd.systemd.services.copy-luks-keys =
    let
      cryptsetupServices =
        lib.map (name: "systemd-cryptsetup@${utils.escapeSystemdPath name}.service") [
          "root"
          "tank"
        ];
    in
    {
      description = "Copy LUKS keys into initrd tmpfs";
      wantedBy = cryptsetupServices;
      requires = [ "key.mount" ];
      after = [ "key.mount" ];
      before = cryptsetupServices;
      conflicts = [
        "initrd-switch-root.target"
        "shutdown.target"
      ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig = {
        Type = "oneshot";
        StandardOutput = "journal+console";
        StandardError = "journal+console";
      };
      path = [ pkgs.coreutils ];
      script = ''
        install -d -m 0700 /run/cryptsetup-keys.d
        install -m 0400 /key/root /run/cryptsetup-keys.d/root
        install -m 0400 /key/tank /run/cryptsetup-keys.d/tank
        echo 'Copied LUKS keys from /key into initrd tmpfs'
      '';
    };

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
                    keyFile = "/run/cryptsetup-keys.d/root";
                    crypttabExtraOpts = [ "x-initrd.attach" ];
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
            settings = {
              keyFile = "/run/cryptsetup-keys.d/tank";
              crypttabExtraOpts = [ "x-initrd.attach" ];
            };
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
