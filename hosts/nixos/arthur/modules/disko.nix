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

    # NOTE: for `config.system.build.vmWithDisko`
    memSize = 2048;
    imageBuilder.copyNixStoreThreads = 8;
  };

  # Prevent disko-generated swapDevices fstab entry — the `resume=` kernel
  # parameter (from `resumeDevice = true`) already causes systemd-fstab-generator
  # to create and activate the swap unit; having both produces a harmless but
  # noisy "Duplicate entry in /etc/fstab" warning.
  swapDevices = lib.mkForce [ ];

  # zram swap (compressed in-RAM, complements disk swap)
  zramSwap.enable = true;

  # Ensure `/persist` and `/var/log` are mounted early for `impermanence` bind mounts
  fileSystems."/persist".neededForBoot = true;
  fileSystems."/var/log".neededForBoot = true;

  # Persistent-disk variant of vmWithDisko — survives VM restarts so you can
  # test hibernation (resume from swap) and impermanence rollback across reboots.
  #   nix run .#nixosConfigurations.arthur.config.system.build.vmWithDiskoPersistent
  #   nix run .#nixosConfigurations.arthur.config.system.build.vmWithDiskoPersistent -- --reset
  system.build.vmWithDiskoPersistent =
    let
      vmVariant = config.virtualisation.vmVariantWithDisko;
      diskoImages = vmVariant.system.build.diskoImages;
      vmRunner = vmVariant.system.build.vm;
      diskNames = builtins.attrNames config.disko.devices.disk;
      inherit (config.networking) hostName;
    in
    pkgs.writeShellScriptBin "disko-vm-persistent" ''
      set -euo pipefail

      state_dir="''${DISKO_VM_STATE_DIR:-''${XDG_DATA_HOME:-$HOME/.local/share}/disko-vm/${hostName}}"
      mkdir -p "$state_dir"
      export tmp="$state_dir"

      if [ "''${1:-}" = "--reset" ]; then
        echo "Resetting VM disk images in $state_dir..."
        ${lib.concatMapStringsSep "\n    " (
          name: ''rm -f "$state_dir"/${lib.escapeShellArg name}.qcow2''
        ) diskNames}
        shift
      fi

      ${lib.concatMapStringsSep "\n    " (name: ''
        if [ ! -f "$state_dir"/${lib.escapeShellArg name}.qcow2 ]; then
          echo "Creating persistent disk overlay: $state_dir/${name}.qcow2"
          ${lib.getExe' pkgs.qemu "qemu-img"} create -f qcow2 \
            -b ${diskoImages}/${lib.escapeShellArg name}.qcow2 \
            -F qcow2 "$state_dir"/${lib.escapeShellArg name}.qcow2
        fi'') diskNames}

      exec ${vmRunner}/bin/run-*-vm "$@"
    '';

  virtualisation.vmVariantWithDisko.virtualisation = {
    fileSystems."/persist".neededForBoot = true;
    fileSystems."/var/log".neededForBoot = true;
    qemu.options = [
      "-serial"
      "stdio"
    ];
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
