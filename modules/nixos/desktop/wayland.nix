{ inputs, config, lib, pkgs, ... }:

let
  cfg = config.reo101.wayland;
in
{
  imports = [
    # inputs.niri.nixosModules.niri
    inputs.stylix.nixosModules.stylix
  ];

  options = {
    reo101.wayland = {
      # TODO: better naming
      enable = lib.mkEnableOption "reo101 Wayland config";
    };
  };

  config = lib.mkIf cfg.enable {
    stylix = {
      enable = true;
      image = pkgs.fetchurl {
        url = "https://media.baraag.net/media_attachments/files/114/343/416/726/247/325/original/202ab96f97ed846a.jpg";
        hash = "sha256-3h7A8NKJ045NZ+RSaPNnWDyfA7+W5RbUzCJTEJWhKlY=";
      };
      # cursor = {
      #   name = "Ukiyo";
      #   package = inputs.ukiyo.packages.${pkgs.hostPlatform.system}.default;
      #   size = 32;
      # };
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
        # pkgs.xdg-desktop-portal
        # pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-gnome
        # NOTE: enabled from `xdg.wlr.enable`
        # pkgs.xdg-desktop-portal-wlr
      ];
      config.common = {
        default = [ "wlr" ];

        "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
        "org.freedesktop.impl.portal.RemoteDesktop" = [ "gnome" ];
      };
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
      type = "fcitx5";

      fcitx5 = {
        waylandFrontend = true;

        addons = with pkgs; [
          fcitx5-mozc
          fcitx5-gtk
        ];
      };
    };

    services.libinput = {
      enable = true;
      mouse.accelProfile = "flat";
      touchpad.accelProfile = "flat";
    };
  };
}
