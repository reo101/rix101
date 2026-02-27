#!/usr/bin/env nu

# Recursively delete a btrfs subvolume and all its children
def delete_subvolume_recursively [path: string] {
  ^btrfs subvolume list -o $path
  | lines
  | parse "ID {id} gen {gen} top level {level} path {path}"
  | get path
  | each { |subvol| delete_subvolume_recursively $"/mnt/($subvol)" }

  ^btrfs subvolume delete $path
}

mkdir /mnt
^mount -t btrfs -o subvol=/ /dev/disk/by-partlabel/nixos /mnt

if ("/mnt/root" | path exists) {
  delete_subvolume_recursively "/mnt/root"
}

^btrfs subvolume create /mnt/root
^umount /mnt
