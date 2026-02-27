{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  boot.initrd.supportedFilesystems = [ "btrfs" ];
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.storePaths = [
    "${lib.getExe pkgs.btrfs-progs}"
    "${lib.getExe pkgs.nushell}"
    "${lib.getExe' pkgs.util-linux "mount"}"
    "${lib.getExe' pkgs.util-linux "umount"}"
    "${./rollback.nu}"
  ];

  # Roll back root subvolume to blank state on every boot
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
      ${lib.getExe pkgs.nushell} ${./rollback.nu}
    '';
  };

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      # Crash dumps for `coredumpctl`
      "/var/lib/systemd/coredump"
    ];
    files = [
      # Stable machine identifier used by `systemd`, `journald`, `D-Bus`, etc.
      "/etc/machine-id"
    ];
  };
}
