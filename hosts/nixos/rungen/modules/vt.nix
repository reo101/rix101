{
  config,
  pkgs,
  lib,
  ...
}:
{
  services.xserver.xkb = {
    layout = "us,bg";
    variant = ",phonetic";
    options = "grp:lalt_lshift_toggle";
  };

  services.getty.autologinUser = config.rix101.wayland.user;

  services.kmscon = {
    enable = true;
    package = pkgs.kmscon;

    useXkbConfig = true;
    hwRender = true;
    fonts = [ config.rix101.wayland.stylix.fonts.monospace ];
  };
}
