{ inputs, config, lib, pkgs, ... }:

{
  imports = [
    # inputs.niri.nixosModules.niri
  ];

  environment.sessionVariables = {
    # If cursor becomes invisible
    # WLR_NO_HARDWARE_CURSORS = "1";
    # Hint electron apps to use wayland
    NIXOS_OZONE_WL = "0";
    # Firefox Wayland
    MOZ_ENABLE_WAYLAND = "1";
    QT_WAYLAND_DISABLE_DECORATION = "1";
  };

  services.greetd = {
    enable = true;
    package = pkgs.greetd.tuigreet;
    settings = {
      terminal = {
        vt = 1;
      };
      default_session = {
        user = "reo101";
        command = "${lib.getExe pkgs.greetd.tuigreet} --cmd ${lib.getExe' pkgs.niri "niri-session"}";
        # command = "${lib.getExe pkgs.greetd.tuigreet} --cmd ${lib.getExe' config.programs.river.package "river"}";
      };
    };
  };

  programs.river = {
    enable = true;
    package = pkgs.river;
  };

  # Enable desktop portals
  xdg.portal = {
    enable = true;
    wlr = {
      enable = true;
    };
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-wlr
    ];
    # TODO: research <https://github.com/flatpak/xdg-desktop-portal/blob/1.18.1/doc/portals.conf.rst.in>
    config.common.default = "*";
  };

  environment.systemPackages = with pkgs; [
    niri
    legcord
    wl-clipboard
    wlr-randr
    grim
    slurp
  ];

  # Sound
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  i18n.inputMethod = {
    enable = true;
    type = "ibus";
    ibus.engines = with pkgs.ibus-engines; [
      mozc
    ];
  };

  services.libinput = {
    enable = true;
    mouse.accelProfile = "flat";
    touchpad.accelProfile = "flat";
  };
}
