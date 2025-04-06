{ inputs, config, lib, pkgs, ... }:

{
  imports = [
    # inputs.niri.nixosModules.niri
    inputs.stylix.nixosModules.stylix
  ];

  stylix = {
    enable = true;
    image = pkgs.fetchurl {
      url = "https://w.wallhaven.cc/full/0p/wallhaven-0p52o3.jpg";
      hash = "sha256-nmbu6KOm8ypgZVKg1KnGcbC5AfX/df2CeTjZUyLpG04=";
    };
    cursor = {
      name = "Ukiyo";
      package = inputs.ukiyo.packages.${pkgs.hostPlatform.system}.default;
      size = 32;
    };
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font Mono";
      };
      serif = config.stylix.fonts.monospace;
      sansSerif = config.stylix.fonts.monospace;
      # emoji = config.stylix.fonts.monospace;
      emoji = {
        package = pkgs.noto-fonts-emoji;
        name = "Noto Color Emoji";
      };
    };
  };

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    nerd-fonts.fira-code
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
