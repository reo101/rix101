{ inputs, lib, pkgs, config, ... }:

{
  home = {
    username = "maria";
    homeDirectory = "/home/maria";
    stateVersion = "25.11";
    sessionPath = [ "$HOME/.local/bin" ];
  };

  programs.home-manager.enable = true;
  programs.bash.enable = true;

  # XFCE theming — Mint-Y-Dark (Linux Mint XFCE style)
  xfconf.settings = {
    # GTK theme, icons, cursor, fonts
    xsettings = {
      "Net/ThemeName" = "Mint-Y-Dark";
      "Net/IconThemeName" = "Mint-Y-Dark";
      "Gtk/CursorThemeName" = "Bibata-Modern-Classic";
      "Gtk/CursorThemeSize" = 24;
      "Gtk/FontName" = "Noto Sans 10";
      "Xft/Antialias" = 1;
      "Xft/HintStyle" = "hintslight";
      "Xft/RGBA" = "rgb";
    };

    # Window manager theme
    xfwm4 = {
      "general/theme" = "Mint-Y-Dark";
      "general/title_font" = "Noto Sans Bold 9";
    };

    # Bottom panel with Whisker Menu (Mint-style layout)
    xfce4-panel = {
      "configver" = 2;
      "panels" = [ 1 ];
      "panels/panel-1/position" = "p=8;x=0;y=0";
      "panels/panel-1/length" = 100.0;
      "panels/panel-1/position-locked" = true;
      "panels/panel-1/size" = { type = "uint"; value = 40; };
      "panels/panel-1/plugin-ids" = [ 1 2 3 4 5 6 7 8 ];
      "plugins/plugin-1" = "whiskermenu";
      "plugins/plugin-2" = "separator";
      "plugins/plugin-2/expand" = false;
      "plugins/plugin-2/style" = { type = "uint"; value = 0; };
      "plugins/plugin-3" = "tasklist";
      "plugins/plugin-3/show-labels" = true;
      "plugins/plugin-3/flat-buttons" = true;
      "plugins/plugin-4" = "separator";
      "plugins/plugin-4/expand" = true;
      "plugins/plugin-4/style" = { type = "uint"; value = 0; };
      "plugins/plugin-5" = "systray";
      "plugins/plugin-5/square-icons" = true;
      "plugins/plugin-6" = "pulseaudio";
      "plugins/plugin-6/enable-keyboard-shortcuts" = true;
      "plugins/plugin-7" = "clock";
      "plugins/plugin-7/digital-format" = "%Y-%m-%d  %H:%M";
      "plugins/plugin-8" = "actions";
    };

    # Desktop icons
    xfce4-desktop = {
      "desktop-icons/style" = 2;
      "desktop-icons/file-icons/show-home" = true;
      "desktop-icons/file-icons/show-filesystem" = true;
      "desktop-icons/file-icons/show-trash" = true;
      "desktop-icons/file-icons/show-removable" = true;
    };
  };
}
