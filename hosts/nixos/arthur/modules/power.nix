{ ... }:
{
  # Battery charge thresholds to keep the battery between 75% and 80% to reduce wear
  # (since it's plugged in most of the time)
  services.tlp.settings = {
    START_CHARGE_THRESH_BAT0 = 75;
    STOP_CHARGE_THRESH_BAT0 = 80;
  };

  # ZFS hibernation support
  # <https://github.com/NixOS/nixpkgs/blob/a292fd0eb0e40892adea0a08b9bb7ed3835c296b/nixos/modules/tasks/filesystems/zfs.nix#L704-L707>
  boot.zfs.allowHibernation = true;
  # Required by the above (hard assertion); disables `-f` on `zpool import`
  # to prevent data corruption on resume. If boot fails after a dirty
  # import (e.g. live USB), add `zfs_force=1` to the kernel cmdline once.
  boot.zfs.forceImportRoot = false;

  systemd.targets = {
    sleep.enable = true;
    suspend.enable = true;
    hibernate.enable = true;
    hybrid-sleep.enable = true;
  };

  # Power management: hibernate on lid close
  services.logind.settings.Login = {
    HandleLidSwitch = "hibernate";
    HandleLidSwitchExternalPower = "suspend";
  };
}
