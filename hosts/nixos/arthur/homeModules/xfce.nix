{ lib, pkgs, ... }:

let
  mkUint = value: {
    type = "uint";
    inherit value;
  };

  panelId = 1;
  panelPath = "panels/panel-${builtins.toString panelId}";

  panelPlugins = [
    {
      id = 1;
      type = "whiskermenu";
    }
    {
      id = 2;
      type = "separator";
      settings = {
        expand = false;
        style = mkUint 0;
      };
    }
    {
      id = 3;
      type = "tasklist";
      settings = {
        show-labels = true;
        flat-buttons = true;
      };
    }
    {
      id = 4;
      type = "separator";
      settings = {
        expand = true;
        style = mkUint 0;
      };
    }
    {
      id = 9;
      type = "pager";
      settings = {
        # Keep the overview compact while still showing all desktops.
        rows = mkUint 1;
        miniature-view = true;
      };
    }
    {
      id = 5;
      type = "systray";
      settings = {
        square-icons = true;
      };
    }
    {
      id = 6;
      type = "pulseaudio";
      settings = {
        enable-keyboard-shortcuts = true;
      };
    }
    # {
    #   id = 10;
    #   type = "xfce4powermanager";
    # }
    {
      id = 7;
      type = "clock";
      settings = {
        digital-format = "%Y-%m-%d  %H:%M";
      };
    }
    {
      id = 8;
      type = "actions";
    }
  ];

  mkPluginAttrs =
    plugin:
    let
      pluginPath = "plugins/plugin-${builtins.toString plugin.id}";
      pluginSettings = lib.mapAttrs' (name: value: lib.nameValuePair "${pluginPath}/${name}" value) (
        plugin.settings or { }
      );
    in
    { "${pluginPath}" = plugin.type; } // pluginSettings;

  xfce4PanelSettings = lib.mkMerge (
    [
      {
        configver = 2;
        panels = [ panelId ];
        "${panelPath}/position" = "p=8;x=0;y=0";
        "${panelPath}/length" = 100.0;
        "${panelPath}/position-locked" = true;
        "${panelPath}/size" = mkUint 40;
        "${panelPath}/plugin-ids" = lib.map (plugin: plugin.id) panelPlugins;
      }
    ]
    ++ lib.map mkPluginAttrs panelPlugins
  );
in
{
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
      "general/workspace_count" = mkUint 3;
      "general/workspace_names" = [
        "Main"
        "Web"
        "Media"
      ];
      # Prevent accidental workspace switching when scrolling on the desktop.
      "general/scroll_workspaces" = false;
    };

    # Bottom panel with Whisker Menu (Mint-style layout)
    xfce4-panel = xfce4PanelSettings;

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
