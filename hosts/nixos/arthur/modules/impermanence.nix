{
  inputs,
  ...
}:
{
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  boot.initrd.systemd.enable = true;

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
