{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  boot.zfs.allowHibernation = true;
  boot.zfs.forceImportRoot = false;

  boot.kernelParams = [
    "mem_sleep_default=deep"
    "acpi_sleep=nonvs"
    "pci=noaer"
    "resume=d209806f-967f-4a02-8d7d-0558efb77a03"
  ];

  boot.resumeDevice = "/dev/nvme0n1p3";

  systemd.targets = {
    sleep.enable = true;
    suspend.enable = true;
    hibernate.enable = true;
    hybrid-sleep.enable = true;
  };

  virtualisation.vmVariantWithDisko = {
    boot.zfs.allowHibernation = true;
    boot.zfs.forceImportRoot = false;
  };

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandlePowerKey = "suspend";
    HandlePowerKeyLongPress = "poweroff";
  };
}
