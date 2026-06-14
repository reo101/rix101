{ inputs, pkgs, config, ... }:

{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia = {
    enable = true;
    systemd.enable = false;
    settings = {
      bar.main = {
        position = "right";
        enabled = true;
        reserve_space = true;
        thickness = 34;
        background_opacity = 1.0;
        border_width = 0.0;
        radius = 12;
        radius_top_right = 0;
        radius_bottom_right = 0;
        margin_ends = 0;
        margin_edge = 0;
        padding = 14;
        widget_spacing = 6;
        scale = 1.0;
        shadow = true;
        auto_hide = false;
        capsule = true;

        start = [
          "control-center"
          # TODO: `iwd` support; leave the network widget off the bar for now.
          "bluetooth"
        ];
        center = [ "workspaces" ];
        end = [
          "tray"
          "battery"
          "clock"
        ];
      };
      theme = {
        mode = "dark";
        source = "wallpaper";
        builtin = "Tokyo-Night";
        wallpaper_scheme = "m3-fruit-salad";
      };
      backdrop = {
        enabled = true;
        blur_intensity = 0.2;
        tint_intensity = 0.6;
      };
      brightness = {
        enable_ddcutil = true;
      };
      shell = {
        avatar_path = "${pkgs.fetchurl {
          url = "https://github.com/${config.home.username}.png";
          hash = "sha256-4OILsWeqJjMLLYQsraGNX+hcpfgXdbJ9RPyiKfW3DG0=";
        }}";
        corner_radius_scale = 0.5;
        font_family = config.stylix.fonts.sansSerif.name;
        launch_apps_as_systemd_services = true;
        niri_overview_type_to_launch_enabled = true;
        settings_show_advanced = true;
        show_location = true;
        clipboard_enabled = true;
        clipboard_history_max_entries = 100;
        clipboard_auto_paste = "auto";
        panel = {
          transparency_mode = "glass";
          open_near_click_control_center = true;
          borders = true;
          shadow = true;
          launcher_placement = "centered";
          clipboard_placement = "centered";
          control_center_placement = "attached";
          wallpaper_placement = "attached";
          session_placement = "attached";
        };
        screen_corners = {
          enabled = false;
        };
      };
      battery = {
        warning_threshold = 30;
      };
      dock = {
        enabled = false;
      };
      plugins = {
        enabled = [ "noctalia/screen_recorder" ];
      };
      lockscreen_widgets = {
        enabled = false;
        schema_version = 2;
        widget_order = [ "lockscreen-login-box@eDP-1" ];
        grid = {
          cell_size = 16;
          major_interval = 4;
          visible = true;
        };
        widget = {
          "lockscreen-login-box@eDP-1" = {
            box_height = 0.0;
            box_width = 0.0;
            cx = 1024.0;
            cy = 1157.0;
            output = "eDP-1";
            rotation = 0.0;
            type = "login_box";
            settings = {
              background_color = "surface_variant";
              background_opacity = 0.88;
              background_radius = 12.0;
              input_opacity = 1.0;
              input_radius = 6.0;
              show_login_button = true;
            };
          };
        };
      };
      location = {
        auto_locate = true;
        # address = "Sofia, Bulgaria";
      };
      weather = {
        enabled = true;
        effects = true;
        unit = "metric";
      };
      nightlight = {
        enabled = false;
        temperature_day = 6500;
        temperature_night = 4000;
      };
      notification = {
        enable_daemon = true;
        position = "top_right";
      };
      audio = {
        enable_overdrive = false;
        enable_sounds = false;
      };
      wallpaper = {
        enabled = true;
        directory = "${config.xdg.dataHome}/wallpapers";
        automation = {
          recursive = true;
        };
      };
      widget = {
        battery = {
          display_mode = "glyph";
          show_label = true;
          hide_when_plugged = false;
          hide_when_full = false;
        };
        clock = {
          format = "{:%H:%M:%S}";
          vertical_format = "{:%H\n%M\n%S}";
          tooltip_format = "{:%A, %d %B %Y}";
          color = "primary";
        };
        control-center = {
          custom_image = "${pkgs.fetchurl {
            url = "https://github.com/${config.home.username}.png";
            hash = "sha256-4OILsWeqJjMLLYQsraGNX+hcpfgXdbJ9RPyiKfW3DG0=";
          }}";
          custom_image_colorize = true;
        };
        workspaces = {
          display = "none";
          hide_when_empty = false;
        };
      };
    };
  };
}
