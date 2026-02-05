{ inputs, lib, ... }:
{
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  boot.initrd.supportedFilesystems = [ "btrfs" ];

  # Roll back root subvolume to blank state on every boot
  boot.initrd.postDeviceCommands =
    lib.mkAfter
      # bash
      ''
        mkdir -p /mnt
        mount -t btrfs -o subvol=/ /dev/disk/by-partlabel/nixos /mnt

        # Recursively delete old root subvolume (NixOS may create nested subvols)
        delete_subvolume_recursively() {
          IFS=$'\n'
          for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
            delete_subvolume_recursively "/mnt/$i"
          done
          btrfs subvolume delete "$1"
        }

        if [ -e /mnt/root ]; then
          delete_subvolume_recursively /mnt/root
        fi

        btrfs subvolume create /mnt/root
        umount /mnt
      '';

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/lib/systemd/coredump"
    ];
    files = [
      "/etc/machine-id"
    ];
  };
}
