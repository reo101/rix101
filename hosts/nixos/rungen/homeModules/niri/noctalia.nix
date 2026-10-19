{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:

let
  fennelGlobals = lib.concatStringsSep "," [
    "barWidget"
    "ipairs"
    "math"
    "noctalia"
    "panel"
    "string"
    "table"
    "tonumber"
    "tostring"
    "type"
    "ui"
  ];
  fennelPlugin =
    name: src: entries:
    pkgs.runCommandLocal "noctalia-${name}"
      {
        nativeBuildInputs = [
          pkgs.custom.fennel
          pkgs.luau
        ];
        inherit src;
      }
      ''
        mkdir "$out"
        cp "$src/plugin.toml" "$out/"
        for entry in ${lib.escapeShellArgs entries}; do
          fennel --correlate --globals-only ${lib.escapeShellArg fennelGlobals} \
            --compile "$src/$entry.fnl" > "$out/$entry.luau"
          luau-compile "$out/$entry.luau" >/dev/null
        done
      '';
  taskwarriorPlugin = fennelPlugin "taskwarrior" ./plugins/taskwarrior [
    "widget"
    "panel"
  ];
  netpathPlugin = fennelPlugin "netpath" ./plugins/netpath [
    "widget"
    "panel"
  ];
in
{
  # HACK: Home Manager moved its Noctalia module; upstream still disables the old path.
  disabledModules = [ "programs/noctalia" ];

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
          "group:status"
          "cpu"
          "group:tools"
        ];
        center = [ "workspaces" ];
        end = [
          "media"
          "tray"
          "battery"
          "clock"
        ];
        capsule_group = [
          {
            id = "status";
            members = [
              "network"
              "netpath"
              "bluetooth"
              "notifications"
              "privacy"
            ];
            padding = 6.0;
            widget_spacing = 6;
          }
          {
            id = "tools";
            members = [
              "timer"
              "notes"
              "taskwarrior"
            ];
            padding = 6.0;
            widget_spacing = 6;
          }
        ];
      };
      theme = {
        mode = lib.mkForce "dark";
        source = lib.mkForce "community";
        builtin = "Catppuccin";
        community_palette = "Kemuri Koke";
        wallpaper_scheme = "m3-content";
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
        screen_time_enabled = true;
        settings_show_advanced = true;
        keyboard_layout.custom_labels = {
          "Bulgarian (traditional phonetic)" = "BG";
          "English (US)" = "EN";
        };
        launcher = {
          show_app_actions = true;
          providers = {
            calculator.prefix = "=";
            panels.prefix = "pan";
            windows.prefix = "win";
          };
        };
        window_switcher.mru = true;
        session.actions = [
          { action = "lock"; countdown_seconds = 0.0; enabled = true; shortcut = "1"; variant = "default"; }
          { action = "logout"; countdown_seconds = 0.0; enabled = true; shortcut = "2"; variant = "default"; }
          { action = "lock_and_suspend"; countdown_seconds = 0.0; enabled = true; shortcut = "3"; variant = "default"; }
          { action = "reboot"; countdown_seconds = 0.0; enabled = true; shortcut = "4"; variant = "default"; }
          { action = "shutdown"; countdown_seconds = 0.0; enabled = true; shortcut = "5"; variant = "destructive"; }
          {
            action = "command";
            command = "systemctl hibernate";
            countdown_seconds = 5.0;
            enabled = true;
            glyph = "hibernate";
            label = "Hibernate";
            shortcut = "6";
            variant = "default";
          }
        ];
        show_location = true;
        clipboard_enabled = true;
        clipboard_history_max_entries = 100;
        clipboard_auto_paste = "auto";
        panel = {
          transparency_mode = "glass";
          open_near_click_control_center = true;
          borders = true;
          shadow = true;
          launcher_placement = "floating";
          launcher_position = "center";
          clipboard_placement = "floating";
          clipboard_position = "center";
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
        device."/org/freedesktop/UPower/devices/headset_dev_2C_BE_EE_5D_BA_6A".warning_threshold = 15;
      };
      control_center = {
        calendar.show_week_numbers = true;
        shortcuts = [
          { type = "wifi"; }
          { type = "bluetooth"; }
          { type = "caffeine"; }
          { type = "notification"; }
          { type = "power_profile"; }
          { type = "screen_recorder"; }
        ];
      };
      dock = {
        enabled = false;
      };
      plugins = {
        auto_update = "none";
        # NOTE: expose only adopted plugins; add another link when enabling one.
        source = [
          {
            name = "official";
            kind = "path";
            location = "${pkgs.linkFarm "noctalia-official-plugins" [
              {
                name = "screen_recorder";
                path = "${inputs.noctalia-plugins-official}/screen_recorder";
              }
              {
                name = "timer";
                path = "${inputs.noctalia-plugins-official}/timer";
              }
              {
                name = "notes";
                path = "${inputs.noctalia-plugins-official}/notes";
              }
            ]}";
            enabled = true;
          }
          {
            name = "rix101";
            kind = "path";
            location = "${pkgs.linkFarm "noctalia-rix101-plugins" [
              {
                name = "taskwarrior";
                path = taskwarriorPlugin;
              }
              {
                name = "netpath";
                path = netpathPlugin;
              }
            ]}";
            enabled = true;
          }
        ];
        enabled = [
          "noctalia/screen_recorder"
          "noctalia/timer"
          "noctalia/notes"
          "reo101/taskwarrior"
          "reo101/netpath"
        ];
      };
      location.auto_locate = false;
      lockscreen = {
        blur_intensity = 0.75;
        blurred_desktop = true;
        tint_intensity = 0.5;
      };
      lockscreen_widgets = {
        enabled = true;
        schema_version = 2;
        widget_order = [ "lockscreen-login-box@eDP-1" ];
        grid = {
          cell_size = 16;
          major_interval = 4;
          visible = true;
        };
        widget = {
          "lockscreen-login-box@eDP-1" = {
            box_height = 196.0;
            box_width = 810.0;
            cx = 1024.0;
            cy = 1157.0;
            output = "eDP-1";
            placement_height = 1280.0;
            placement_width = 2048.0;
            rotation = 0.0;
            type = "login_box";
            settings = {
              background_color = "surface_variant";
              background_opacity = 0.88;
              background_radius = 12.0;
              center_password_text = false;
              input_opacity = 1.0;
              input_radius = 6.0;
              layout = "regular";
              show_caps_lock = true;
              show_keyboard_layout = true;
              show_login_button = true;
              show_media = true;
              show_session_buttons = true;
              show_unlock_hint = true;
              show_weather = true;
            };
          };
        };
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
      system.monitor.enabled = true;
      audio = {
        enable_overdrive = true;
        enable_sounds = true;
      };
      wallpaper = {
        enabled = true;
        directory = "${config.xdg.dataHome}/wallpapers";
        fill_color = "primary";
        fill_mode = "fit";
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
        cpu = {
          type = "sysmon";
          stat = "cpu_usage";
          visualization = "gauge";
          show_glyph = false;
          show_value = false;
        };
        timer.type = "noctalia/timer:bar";
        notes.type = "noctalia/notes:notes";
        taskwarrior.type = "reo101/taskwarrior:taskwarrior";
        netpath.type = "reo101/netpath:netpath";
        media.hide_when_no_media = true;
        network.show_label = false;
        privacy.hide_inactive = true;
        workspaces = {
          show_labels = false;
          hide_when_empty = false;
        };
      };
    };
  };
}
