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

  services.getty.autologinUser = config.reo101.wayland.user;

  services.kmscon = {
    enable = true;
    package = pkgs.kmscon;

    useXkbConfig = true;
    hwRender = true;
    fonts = [ config.reo101.wayland.stylix.fonts.monospace ];
  };
}
