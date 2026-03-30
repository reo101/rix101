{
  lib,
  pkgs,
  ...
}:
{
  boot.supportedFilesystems = {
    # Local, based on `nixpkgs/nixos/modules/profiles/base.nix`
    bcachefs = true;
    # From `nixpkgs/nixos/modules/profiles/base.nix`
    btrfs = true;
    # From `nixpkgs/nixos/modules/profiles/base.nix`
    cifs = true;
    # Local addition for removable media
    exfat = true;
    # From `nixpkgs/nixos/modules/profiles/base.nix`
    f2fs = true;
    # From `nixpkgs/nixos/modules/profiles/base.nix`
    ntfs = true;
    # From `nixpkgs/nixos/modules/profiles/base.nix`
    vfat = true;
    # From `nixpkgs/nixos/modules/profiles/base.nix`
    xfs = true;
    # From `nixpkgs/nixos/modules/profiles/base.nix`
    zfs = true;
  };

  # From `nixpkgs/nixos/modules/profiles/installation-device.nix`
  boot.swraid.enable = true;
  # From `nixpkgs/nixos/modules/profiles/installation-device.nix`, but using `lib.getExe'`
  boot.swraid.mdadmConf = "PROGRAM ${lib.getExe' pkgs.coreutils "true"}";

  # From `nixpkgs/nixos/modules/profiles/base.nix`
  networking.hostId = "8425e349";

  environment.systemPackages = [
    # From `nixpkgs/nixos/modules/profiles/base.nix`: `Btrfs` filesystem repair and recovery
    pkgs.btrfs-progs
    # From `nixpkgs/nixos/modules/profiles/base.nix`: `LUKS` and `dm-crypt` unlock and recovery
    pkgs.cryptsetup
    # Local addition: Ethernet link inspection and tuning
    pkgs.ethtool
    # From `nixpkgs/nixos/modules/profiles/base.nix`: `GPT` partition table repair and editing
    pkgs.gptfdisk
    # Local addition: Low-level Wi-Fi inspection beyond `iwctl`
    pkgs.iw
    # Local addition: Software `RAID` assembly and recovery
    pkgs.mdadm
    # Local addition: `NTFS` mount and repair tooling
    pkgs.ntfs3g
    # From `nixpkgs/nixos/modules/profiles/base.nix`: `NVMe` health checks and namespace management
    pkgs.nvme-cli
    # From `nixpkgs/nixos/modules/profiles/base.nix`: Basic disk partitioning
    pkgs.parted
    # From `nixpkgs/nixos/modules/profiles/base.nix`: `SMART` disk diagnostics
    pkgs.smartmontools
    # From `nixpkgs/nixos/modules/profiles/base.nix`: Packet capture for network debugging
    pkgs.tcpdump
    # Local addition: `XFS` filesystem repair and recovery
    pkgs.xfsprogs
    # Local addition: `ZFS` pool import and recovery tools
    pkgs.zfs
  ];
}
