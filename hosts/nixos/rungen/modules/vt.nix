{ lib, pkgs, config, ... }:
{
  services.xserver.xkb = {
    layout = "us,bg";
    variant = ",phonetic";
    options = "grp:lalt_lshift_toggle";
  };

  services.getty.autologinUser = config.rix101.wayland.user;

  fonts.packages = [
    config.rix101.wayland.stylix.fonts.monospace.package
  ];

  # FIXME: still using old `services.kmscon.fonts` & `extraConfig`)
  stylix.targets.kmscon.enable = false;

  services.kmscon = {
    enable = true;
    package = pkgs.kmscon;

    useXkbConfig = true;
    config = {
      hwaccel = true;
      font-name = config.rix101.wayland.stylix.fonts.monospace.name;
    };
  };
}
