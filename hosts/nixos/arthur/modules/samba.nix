{
  lib,
  pkgs,
  config,
  ...
}:
{
  age.secrets."samba.credentials" = {
    rekeyFile = lib.custom.repoSecret "home/arthur/samba/credentials.age";
  };

  environment.systemPackages = [
    pkgs.cifs-utils
  ];

  # Automount jeeves's `maria` share on first access
  fileSystems."/mnt/maria" = {
    device = "//jeeves.lan/maria";
    fsType = "cifs";
    options = [
      "credentials=${config.age.secrets."samba.credentials".path}"
      "x-systemd.automount"
      "noauto"
      "uid=${toString config.users.users.maria.uid}"
      "gid=${toString config.users.groups.${config.users.users.maria.group}.gid}"
    ];
  };
}
