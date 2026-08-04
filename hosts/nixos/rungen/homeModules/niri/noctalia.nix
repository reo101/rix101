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
in
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
        source = lib.mkForce "wallpaper";
        builtin = "Tokyo-Night";
        wallpaper_scheme = "m3-fruit-salad";
      };
      backdrop = {
        enabled = true;
        blur_intensity = 0.2;
        tint_intensity = 0.4;
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
      };
      control_center.shortcuts = [
        { type = "wifi"; }
        { type = "bluetooth"; }
        { type = "caffeine"; }
        { type = "notification"; }
        { type = "power_profile"; }
        { type = "screen_recorder"; }
      ];
      dock = {
        enabled = false;
      };
      plugins = {
        auto_update = false;
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
            ]}";
            enabled = true;
          }
        ];
        enabled = [
          "noctalia/screen_recorder"
          "noctalia/timer"
          "noctalia/notes"
          "reo101/taskwarrior"
        ];
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
      system.monitor.enabled = true;
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
