{
  config,
  pkgs,
  lib,
  ...
}:
{
  services.xserver = {
    layout = "us,bg";
    xkb = {
      variant = ",phonetic";
      options = "grp:lalt_lshift_toggle";
    };
  };

  services.kmscon = {
    enable = true;
    package = pkgs.kmscon;

    useXkbConfig = true;
    hwRender = true;
    fonts = [ config.reo101.wayland.stylix.fonts.monospace ];
    autologinUser = config.reo101.wayland.user;
  };
}
