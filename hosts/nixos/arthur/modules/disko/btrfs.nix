{
  lib,
  pkgs,
  ...
}:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  disko.devices.disk.main.content = {
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

  # `/var/log` is its own subvolume — mount early for `journald`
  fileSystems."/var/log".neededForBoot = true;

  # Btrfs root rollback — delete and recreate root subvolume on every boot
  boot.initrd.supportedFilesystems = [ "btrfs" ];
  boot.initrd.systemd.storePaths = [
    "${lib.getExe pkgs.btrfs-progs}"
    "${lib.getExe pkgs.nushell}"
    "${lib.getExe' pkgs.util-linux "mount"}"
    "${lib.getExe' pkgs.util-linux "umount"}"
    "${./btrfs-rollback.nu}"
  ];
  boot.initrd.systemd.services.rollback = {
    description = "Rollback BTRFS root subvolume to a pristine state";
    wantedBy = [ "initrd.target" ];
    after = [ "initrd-root-device.target" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    path = [
      pkgs.btrfs-progs
      pkgs.nushell
      pkgs.util-linux
    ];
    script = ''
      ${lib.getExe pkgs.nushell} ${./btrfs-rollback.nu}
    '';
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
