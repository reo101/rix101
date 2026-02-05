{ ... }:
{
  users.users.maria = {
    isNormalUser = true;
    group = "users";
    home = "/data/samba/maria";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE3Lq1KDfCG68MuV3xna5KeD+rPzMO/JaFWpsrB+/h3J arthur->maria@jeeves"
    ];
  };

  services.samba.settings.maria = {
    "path" = "/data/samba/maria";
    "browseable" = "yes";
    "read only" = "no";
    "guest ok" = "no";
    "create mask" = "0644";
    "directory mask" = "0755";
    "valid users" = "maria";
    "force user" = "maria";
    "force group" = "users";
  };
}
