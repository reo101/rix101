{
  inputs,
  lib,
  config,
  ...
}:
{
  imports = [
    inputs.disko-zfs.nixosModules.default
  ];

  boot.loader.grub = {
    enable = true;
    zfsSupport = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  # `head -c 8 /etc/machine-id` (required for ZFS)
  networking.hostId = "2ee611ce";

  disko.devices = {
    disk.main.content = {
      type = "gpt";
      partitions = {
        boot = {
          label = "boot_mbr";
          size = "1M";
          type = "EF02";
          priority = 1;
        };
        ESP = {
          label = "ESP";
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
        zfs = {
          label = "zroot";
          size = "100%";
          content = {
            type = "zfs";
            pool = "zroot";
          };
          priority = 4;
        };
      };
    };

    zpool.zroot = {
      type = "zpool";
      options = {
        ashift = "12";
        autotrim = "on";
        listsnapshots = "on";
      };
      rootFsOptions = {
        acltype = "posixacl";
        atime = "off";
        canmount = "off";
        checksum = "sha512";
        compression = "zstd";
        dnodesize = "auto";
        mountpoint = "none";
        normalization = "formD";
        xattr = "sa";
      };

      datasets = {
        "root" = {
          type = "zfs_fs";
          options.mountpoint = "legacy";
          mountpoint = "/";
          postCreateHook = "zfs snapshot zroot/root@blank";
        };
        "nix" = {
          type = "zfs_fs";
          options = {
            mountpoint = "legacy";
            atime = "off";
          };
          mountpoint = "/nix";
        };
        "persist" = {
          type = "zfs_fs";
          options.mountpoint = "legacy";
          mountpoint = "/persist";
        };
        "persist/home" = {
          type = "zfs_fs";
          options = {
            mountpoint = "legacy";
            "com.sun:auto-snapshot" = "true";
          };
          mountpoint = "/persist/home";
        };
      };
    };
  };

  services.zfs.autoSnapshot.enable = true;

  disko.zfs = {
    enable = true;
    settings = {
      logLevel = "info";
    };
  };

  environment.persistence."/persist".directories = [
    "/home"
    "/var/log"
  ];

  boot.initrd.systemd.services.rollback = {
    description = "Rollback ZFS root dataset to a pristine state";
    wantedBy = [ "initrd.target" ];
    after = [ "zfs-import-zroot.service" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      ${lib.getExe' config.boot.zfs.package "zfs"} rollback -r zroot/root@blank
    '';
  };
}
