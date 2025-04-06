{ inputs, config, lib, pkgs, ... }:

{
  imports = [
    inputs.niri.homeModules.niri
  ];

  home.packages = with pkgs; [
    wofi
    xwayland-satellite
  ];

  services.swww = {
    enable = true;
    package = pkgs.swww;
  };

  programs.niri = {
    enable = true;
    settings = {
      debug = {
        # WARN: needed on Asahi
        render-drm-device = "/dev/dri/renderD128";
      };
      environment = {
        # CLUTTER_BACKEND = "wayland";
        DISPLAY = ":0";
        GDK_BACKEND = "wayland,x11";
        GTK_USE_PORTAL = "1";
        MOZ_ENABLE_WAYLAND = "1";
        NIXOS_OZONE_WL = "1";
        # QT_QPA_PLATFORM = "wayland;xcb";
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
        # SDL_VIDEODRIVER = "wayland";
      };
      spawn-at-startup = lib.map (command: {
        command = lib.toList command;
      }) [
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
        # "${lib.getExe pkgs.waybar}"
        # ["${lib.getExe' pkgs.wl-clipboard-rs "wl-copy"}" "--watch" "cliphist" "store"]
        "${lib.getExe pkgs.wired}"
        "${lib.getExe pkgs.xwayland-satellite}"
      ];
      clipboard.disable-primary = true;
      hotkey-overlay.skip-at-startup = true;
      # screenshot-path = "~/%Y%m%d%H%M%S_Screenshot.png";
      binds = let
        playerctl = lib.getExe pkgs.playerctl;
        wpctl = lib.getExe' pkgs.pipewire "wpctl";
        brillo = lib.getExe pkgs.brillo;
        foot = lib.getExe pkgs.foot;
        ghostty = lib.getExe pkgs.ghostty;
        wofi = lib.getExe pkgs.wofi;
        cliphist = lib.getExe pkgs.cliphist;
        wl-copy = lib.getExe' pkgs.wl-clipboard-rs "wl-copy";
        wayfreeze = lib.getExe pkgs.wayfreeze;
        grimshot = lib.getExe pkgs.sway-contrib.grimshot;
        killall = lib.getExe pkgs.killall;
        grim = lib.getExe pkgs.grim;
        slurp = lib.getExe pkgs.slurp;
      in lib.mergeAttrsList (with config.lib.niri.actions; [
        # Multimedia
        {
          "XF86AudioPlay".action  = spawn "${playerctl}" "play-pause";
          "XF86AudioPause".action = spawn "${playerctl}" "pause";
          "XF86AudioNext".action  = spawn "${playerctl}" "next_track";
          "XF86AudioPrev".action  = spawn "${playerctl}" "prev_track";

          "XF86AudioMute".action = spawn "${wpctl}" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle";

          "XF86AudioRaiseVolume".action = spawn "${wpctl}" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+";
          "XF86AudioLowerVolume".action = spawn "${wpctl}" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-";

          "XF86MonBrightnessUp".action = spawn "${brillo}" "-q" "-u" "300000" "-A" "5";
          "XF86MonBrightnessDown".action = spawn "${brillo}" "-q" "-u" "300000" "-U" "5";
        }

        # Bindings
        {
          "Mod+Return" = { repeat = false; action = spawn "${ghostty}"; };
          "Mod+Shift+Return" = { repeat = false; action = spawn "${foot}"; };

          "Mod+D" = { repeat = false; action = spawn "${wofi}" "--show" "drun"; };

          "Mod+V" = { repeat = false; action = spawn "${cliphist}" "list" "|" "${wofi}" "-dmenu" "|" "${cliphist}" "decode" "|" "${wl-copy}"; };

          # "Mod+Shift+S" = { repeat = false; action = spawn "${wayfreeze}" "--after-freeze-cmd" "${grim} -g $(${slurp}) - | ${wl-copy}; ${killall} wayfreeze";};
          "Mod+Shift+S" = { repeat = false; action = spawn "${wayfreeze}" "--after-freeze-cmd" "${grimshot} --notify --cursor copy area; ${killall} wayfreeze";};

          "Mod+Ctrl+Q" = { repeat = false; action = spawn "sh" "-c" "pgrep swaylock || swaylock"; };

          "Mod+Q" = { repeat = false; action = close-window; };
          "Mod+S".action = switch-preset-column-width;
          "Mod+F".action = maximize-column;
          "Mod+Shift+F".action = fullscreen-window;
          "Mod+W".action = toggle-column-tabbed-display;

          "Mod+Comma".action = consume-window-into-column;
          "Mod+Period".action = expel-window-from-column;
          "Mod+Tab".action = switch-focus-between-floating-and-tiling;
          "Mod+Shift+Space".action = toggle-window-floating;
        }

        # Workspace
        (let
          workspaces =
            builtins.genList
              (i: {
                key = builtins.toString (lib.trivial.mod (i + 1) 10);
                index = i + 1;
              })
              10;
        in lib.mergeAttrsList [
          # Mod+N focus workspace N
          (builtins.listToAttrs (map (w: {
            name = "Mod+" + w.key;
            value = { action.focus-workspace = w.index; };
          }) workspaces))

          # Mod+Shift+N move window to workspace N
          (builtins.listToAttrs (map (w: {
            name = "Mod+Shift+" + w.key;
            value = { action.move-window-to-workspace = w.index; };
          }) workspaces))

          {
            "Mod+H".action = focus-column-or-monitor-left;
            "Mod+J".action = focus-window-or-workspace-down;
            "Mod+K".action = focus-window-or-workspace-up;
            "Mod+L".action = focus-column-or-monitor-right;

            "Mod+Left".action  = focus-column-or-monitor-left;
            "Mod+Down".action  = focus-window-or-workspace-down;
            "Mod+Up".action    = focus-window-or-workspace-up;
            "Mod+Right".action = focus-column-or-monitor-right;

            "Mod+Shift+H".action = move-column-left;
            "Mod+Shift+J".action = move-column-to-workspace-down;
            "Mod+Shift+K".action = move-column-to-workspace-up;
            "Mod+Shift+L".action = move-column-right;

            "Mod+Shift+Left".action  = move-column-left-or-to-monitor-left;
            "Mod+Shift+Down".action  = move-column-to-workspace-down;
            "Mod+Shift+Up".action    = move-column-to-workspace-up;
            "Mod+Shift+Right".action = move-column-right-or-to-monitor-right;
          }
        ])
      ]);

      layout = {
        border = {
          enable = true;
          width = 1;
          active = {
            color = "#5767FF";
          };
          inactive = {
            color = "#5F5A65";
          };
        };
        focus-ring = {
          enable = false;
          width = 1;
          active = {
            color = "#5767FF";
          };
          inactive = {
            color = "#5F5A65";
          };
        };
        shadow = {
          enable = true;
          # color = "#00000070";
          # draw-behind-window = false;
          # inactive-color = null;
          # # offset.x = 0.0;
          # # offset.y = 0.0;
          # softness = 30.0;
          # spread = 5.0;
        };
        insert-hint = {
          enable = false;
          display = {
            color = "rgb(87 103 255 / 50%)";
          };
        };
        preset-column-widths = builtins.genList (i: { proportion = (i + 1) / 4.0; }) 4;
        # [
        #   { proportion = 0.25; }
        #   { proportion = 0.50; }
        #   { proportion = 0.75; }
        #   { proportion = 1.00; }
        # ];
        default-column-width.proportion = 0.5;

        gaps = 8;
        struts = {
          left = 2;
          right = 2;
          top = 2;
          bottom = 2;
        };

        tab-indicator = {
          hide-when-single-tab = true;
          place-within-column = true;
          position = "left";
          corner-radius = 20.0;
          gap = -9.0;
          gaps-between-tabs = 10.0;
          width = 4.0;
          length.total-proportion = 0.1;
        };
      };
      prefer-no-csd = true;
      window-rules = let
        mkMatchRule = {
          appId,
          title ? "",
          openFloating ? false,
        }: let
          baseRule = {
            matches = [
              {
                app-id = appId;
                inherit title;
              }
            ];
          };
          floatingRule =
            if openFloating
            then { open-floating = true; }
            else {};
        in
          baseRule // floatingRule;

        openFloatingApps = builtins.map
          (appId: mkMatchRule {
            appId = appId;
            openFloating = true;
          })
          [
            "^(pavucontrol)"
            "^(Volume Control)"
            "^(dialog)"
            "^(file_progress)"
            "^(confirm)"
            "^(download)"
            "^(error)"
            "^(notification)"
          ];

        floatingRules = openFloatingApps ++ [
          # FIXME: normal `Firefox` window doesn't set a title either
          # (mkMatchRule {
          #   appId = "firefox";
          #   # `Web Scrobbler` plugin doesn't set a title
          #   title = "";
          #   openFloating = true;
          # })
        ];

        windowRules = [
          # Rounded corners
          {
            geometry-corner-radius = let
              corners = ["bottom-left" "bottom-right" "top-left" "top-right"];
              radius = 10.0;
            in lib.genAttrs corners (lib.const radius);
            clip-to-geometry = true;
            draw-border-with-background = false;
          }

          # Floating windows have a shadow
          {
            matches = [
              { is-floating = true; }
            ];
            shadow.enable = true;
          }

          # Screencasted windows are marked
          {
            matches = [
              { is-window-cast-target = true; }
            ];

            border = {
              active.color = "#f38ba8";
              inactive.color = "#7d0d2d";
            };

            shadow = {
              color = "#7d0d2d70";
            };

            tab-indicator = {
              active.color = "#f38ba8";
              inactive.color = "#7d0d2d";
            };
          }

          # Block out sensitive apps from screencasts
          {
            matches = [
              { app-id = "org.telegram.desktop"; }
              { app-id = "app.drey.PaperPlane"; }
              { app-id = "^(dis|arm|leg|ven)cord$"; }
            ];
            block-out-from = "screencast";
          }

          # "Fix" scrolling on browsers and other GTK apps
          {
            matches = [
              { app-id = "^(zen|firefox|chromium-browser|chrome-.*|zen-.*)$"; }
              { app-id = "^(xdg-desktop-portal-gtk)$"; }
            ];
            scroll-factor = 0.3;
          }

          # Open browsers and discord(s) maximized
          {
            matches = [
              { app-id = "^(zen|firefox|chromium-browser|edge|chrome-.*|zen-.*)$"; }
              { app-id = "^(dis|arm|leg|ven)cord$"; }
            ];
            open-maximized = true;
          }

          # Open (some) popups in a floating window
          {
            matches = [
              {
                app-id = "firefox$";
                title = "^Picture-in-Picture$";
              }
              {
                app-id = "zen-.*$";
                title = "^Picture-in-Picture$";
              }
              {
                app-id = "zen-.*$";
                title = ".*Bitwarden Password Manager.*";
              }
              { title = "^Picture in picture$"; }
              { title = "^Discord Popout$"; }
            ];
            open-floating = true;
            default-floating-position = {
              x = 32;
              y = 32;
              relative-to = "top-right";
            };
          }
        ];
      in windowRules ++ floatingRules;
      # TODO: https://github.com/YaLTeR/niri/wiki/Configuration:-Named-Workspaces
      workspaces = {
        "main" = {
          open-on-output = "eDP-1"; # "HDMI-A-1" (external)
        };
      };
      outputs = {
        "eDP-1" = {
          enable = true;
          mode = {
            width = 3024;
            height = 1890;
          };
          position = {
            x = 0;
            y = 0;
          };
          scale = 2;
          variable-refresh-rate = false;
        };
      };
      input = {
        focus-follows-mouse = {
          enable = true;
        };
        warp-mouse-to-focus = false;
        keyboard = {
          repeat-delay = 200;
          repeat-rate = 50;
          track-layout = "global";
          xkb = {
            layout = "us,bg";
            variant = ",phonetic";
            options = "grp:lalt_lshift_toggle";
          };
        };
        mouse = {
          enable = true;
          accel-profile = null;
        };
        touchpad = {
          click-method = "clickfinger";
          dwt = true;
          dwtp = true;
          natural-scroll = true;
          scroll-method = "two-finger";
          tap = false;
        };
      };
    };
  };
}
