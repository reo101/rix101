{
  pkgs,
  lib,
  ...
}:
let
  mapleFont = rec {
    package = pkgs.custom.maple-mono-custom;
    name = package.fontName;
  };
in
{
  services.xserver.xkb = {
    layout = "us,bg";
    variant = ",phonetic";
    options = "grp:lalt_lshift_toggle";
  };

  services.getty = {
    autologinUser = "reo101";
    helpLine = lib.mkForce ''
      The local VT autologins as "reo101" via kmscon.

      Use `sudo -i` for a root shell, `iwctl` for Wi-Fi, and `iso-unlock`
      after inserting your YubiKey to enter its PIN and enable SSH and WireGuard.
    '';
  };

  services.kmscon = {
    enable = true;
    package = pkgs.kmscon;

    useXkbConfig = true;
    hwRender = true;
    fonts = [ mapleFont ];
  };
}
