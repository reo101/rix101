{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  services.tftpd = {
    enable = false;
    path = "/data/tftp";
  };
  services.atftpd = {
    enable = false;
    root = "/data/tftp";
    extraOptions = [
      "--verbose=7"
    ];
  };

  networking.firewall.allowedUDPPorts = [
    69
  ];
}
