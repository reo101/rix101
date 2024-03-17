{ lib, pkgs, config, ... }:
{
  environment.systemPackages = with pkgs; [
  ];

  # TODO: smbpasswd -a <USER>

  services.samba-wsdd = {
    # make shares visible for Windows clients
    enable = true;
    openFirewall = true;
  };

  services.samba = {
    enable = true;
    package = pkgs.sambaFull;
    openFirewall = true;
    securityType = "user";
    extraConfig = ''
      # Files
      workgroup = WORKGROUP
      server string = Jeeves
      netbios name = jeeves
      security = user
      #use sendfile = yes
      #max protocol = smb2
      # NOTE: localhost is the ipv6 localhost ::1
      hosts allow = 192.168.0. 192.168.1. 10.100.0. 127.0.0.1 localhost
      hosts deny = 0.0.0.0/0
      guest account = nobody
      map to guest = bad user

      # Symlinks
      allow insecure wide links = yes

      # Printers
      load printers = yes
      printing = cups
      printcap name = cups
    '';
    shares = {
      public = {
        path = "/data/samba/public";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "jeeves";
        "force group" = "users";
      };
      private = {
        path = "/data/samba/private";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "jeeves";
        "force group" = "users";
        "follow symlinks" = "yes";
        "wide links" = "yes";
      };
    };
  };
}
