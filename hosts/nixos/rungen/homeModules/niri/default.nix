{
  inputs,
  config,
  lib,
  osConfig ? null,
  pkgs,
  ...
}:

{
  imports = [
    inputs.niri.homeModules.niri
    ./noctalia.nix
    # ./glue.nix
    # {
    #   options = let
    #     inherit (lib) types;
    #   in {
    #     programs.niri.settings.layer-rules = lib.mkOption {
    #       type = types.nullOr (types.listOf (types.submodule {
    #         options.place-within-backdrop = lib.mkOption {
    #           type = types.bool;
    #           default = false;
    #         };
    #       }));
    #     };
    #   };
    # }
  ];

  home.packages = with pkgs; [
    wofi
    xwayland-satellite
  ];

  programs.niri = {
    enable = true;
    # package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
    package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable.overrideAttrs (oldAttrs: let
      src = pkgs.fetchFromGitHub {
        owner = "niri-wm";
        repo = "niri";
        rev = "4a7e443b6c816e4f673f6e25cc0a5aa37697d667";
        hash = "sha256-YfWsg2FyXyv0awYazmlufoKSUUzGUZQUHA/VP9fmMLI=";
      };
    in {
      inherit src;
      cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
        inherit src;
        hash = "sha256-Fv3uClwuuAAGTQ7ujuAQW7xCoYFCw4q9QC08Z7Q7Hdk=";
      };
    });
    # Append raw KDL for options not yet in niri-flake's settings schema
    config = lib.mkOptionDefault (with inputs.niri.lib.kdl; [
      (plain "window-rule" [
        # (leaf "match" {
        #   app-id = "^ghostty$";
        # })
        (plain "background-effect" [
          (leaf "blur" true)
          (leaf "xray" false)
        ])
      ])
    ]);
    settings = {
      environment = {
        # CLUTTER_BACKEND = "wayland";
        DISPLAY = ":0";
        GDK_BACKEND = "wayland";
        GTK_USE_PORTAL = "1";
        MOZ_ENABLE_WAYLAND = "1";
        NIXOS_OZONE_WL = "1";
        # QT_QPA_PLATFORM = "wayland;xcb";
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
        # SDL_VIDEODRIVER = "wayland";
        # XDG_SESSION_TYPE = "wayland";
      };
      spawn-at-startup =
        lib.map
          (command: {
            command = lib.toList command;
          })
          [
            "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
            # NOTE: using Noctalia Shell for notifications
            # "${lib.getExe pkgs.wired}"
            # Defer xwayland-satellite until Noctalia registers on D-Bus
            # Fixes notifications going to X11 instead of Noctalia on boot/resume
            "sh -c 'while ! ${lib.getExe' pkgs.dbus "dbus-send"} --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames 2>/dev/null | grep -q org.freedesktop.Notifications; do sleep 0.1; done; ${lib.getExe pkgs.xwayland-satellite}'"
            "${lib.getExe pkgs.mpd-discord-rpc}"
          ];
      clipboard.disable-primary = true;
      hotkey-overlay.skip-at-startup = true;
      binds =
        let
          playerctl = lib.getExe pkgs.playerctl;
          wpctl = lib.getExe' pkgs.wireplumber "wpctl";
          brightnessctl = lib.getExe pkgs.brightnessctl;
          foot = lib.getExe pkgs.foot;
          ghostty = lib.getExe config.programs.ghostty.package;
          wofi = lib.getExe pkgs.wofi;
          cliphist = lib.getExe pkgs.cliphist;
          wl-copy = lib.getExe' pkgs.wl-clipboard-rs "wl-copy";
          wayfreeze = lib.getExe pkgs.wayfreeze;
          grimshot = lib.getExe pkgs.sway-contrib.grimshot;
          killall = lib.getExe pkgs.killall;
          grim = lib.getExe pkgs.grim;
          slurp = lib.getExe pkgs.slurp;
          tesseract = lib.getExe pkgs.tesseract;
          emacsclient = lib.getExe' config.programs.emacs.package "emacsclient";
          niri = lib.getExe config.programs.niri.package;
          jq = lib.getExe pkgs.jq;
          defaultLockCommand = [
            (lib.getExe' pkgs.systemd "loginctl")
            "lock-session"
          ];
          lockCommand =
            if osConfig != null then
              lib.attrByPath [ "reo101" "wayland" "lock" "command" ] defaultLockCommand osConfig
            else
              defaultLockCommand;
        in
        lib.mergeAttrsList (
          with config.lib.niri.actions;
          [
            # Multimedia
            {
              "XF86AudioPlay".action = spawn "${playerctl}" "play-pause";
              "XF86AudioPause".action = spawn "${playerctl}" "pause";
              "XF86AudioNext".action = spawn "${playerctl}" "next";
              "XF86AudioPrev".action = spawn "${playerctl}" "previous";

              "XF86AudioMute".action = spawn "${wpctl}" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle";

              "XF86AudioRaiseVolume".action = spawn "${wpctl}" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+";
              "XF86AudioLowerVolume".action = spawn "${wpctl}" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-";

              # Screen
              "XF86MonBrightnessUp".action = spawn "${brightnessctl}" "set" "10%+";
              "XF86MonBrightnessDown".action = spawn "${brightnessctl}" "set" "10%-";

              # Keyboard
              "Shift+XF86MonBrightnessUp".action = spawn "${
                brightnessctl
              }" "--device=framework_laptop::kbd_backlight" "set" "10%+";
              "Shift+XF86MonBrightnessDown".action = spawn "${
                brightnessctl
              }" "--device=framework_laptop::kbd_backlight" "set" "10%-";
            }

            # Applications
            {
              "Mod+E" = {
                repeat = false;
                action = spawn "${emacsclient}" "-c" "-a" "";
              };
            }

            # Bindings
            {
              "Mod+Return" = {
                repeat = false;
                action = spawn "${ghostty}";
              };
              "Mod+Shift+Return" = {
                repeat = false;
                action = spawn "${foot}";
              };

              "Mod+D".action.spawn = [
                "noctalia-shell"
                "ipc"
                "call"
                "launcher"
                "toggle"
              ];
              "Mod+Shift+D" = {
                repeat = false;
                action = spawn "${wofi}" "--show" "drun";
              };

              "Mod+Shift+S" = {
                repeat = false;
                action = { screenshot = []; };
              };

              "Mod+V" = {
                repeat = false;
                action =
                  spawn "${cliphist}" "list" "|" "${wofi}" "-dmenu" "|" "${cliphist}" "decode" "|"
                    "${wl-copy}";
              };

              # Dynamic Cast Target (Presentation)
              "Mod+P" = {
                repeat = false;
                action = spawn "sh" "-c" "${niri} msg action set-dynamic-cast-window --id $(${niri} msg --json pick-window | ${jq} .id)";
                # action = spawn "sh" "-c" "${niri} msg action set-dynamic-cast-window --id $(${niri} msg --json list-windows | ${jq} '.[] | select(.is_active) | .id' | head -1)";
              };
              "Mod+Shift+P" = {
                repeat = false;
                action = spawn "sh" "-c" "${niri} msg action clear-dynamic-cast-target";
              };
              "Mod+Ctrl+P" = {
                repeat = false;
                action = spawn "sh" "-c" "${niri} msg action set-dynamic-cast-monitor";
              };
              "Mod+Ctrl+Q" = {
                repeat = false;
                action.spawn = lockCommand;
              };

              "Mod+Q" = {
                repeat = false;
                action = close-window;
              };
              "Mod+Shift+Q" = {
                repeat = false;
                action = spawn "sh" "-c" "kill -9 $(${niri} msg --json focused-window | ${jq} '.pid')";
              };
              "Mod+C".action = center-column;
              "Mod+S".action = switch-preset-column-width;
              "Mod+F".action = maximize-column;
              "Mod+Shift+F".action = fullscreen-window;
              "Mod+Ctrl+Shift+F".action = toggle-windowed-fullscreen;
              "Mod+W".action = toggle-column-tabbed-display;

              "Mod+Comma".action = consume-window-into-column;
              "Mod+Period".action = expel-window-from-column;
              "Mod+Tab".action = switch-focus-between-floating-and-tiling;
              "Mod+Shift+Space".action = toggle-window-floating;
            }

            # Workspace
            (
              let
                workspaces = builtins.genList (i: {
                  key = builtins.toString (lib.trivial.mod (i + 1) 10);
                  index = i + 1;
                }) 10;
              in
              lib.mergeAttrsList [
                # Mod+N focus workspace N
                (builtins.listToAttrs (
                  map (w: {
                    name = "Mod+" + w.key;
                    value = {
                      action.focus-workspace = w.index;
                    };
                  }) workspaces
                ))

                # Mod+Shift+N move window to workspace N
                (builtins.listToAttrs (
                  map (w: {
                    name = "Mod+Shift+" + w.key;
                    value = {
                      action.move-window-to-workspace = w.index;
                    };
                  }) workspaces
                ))

                {
                  "Mod+H".action = focus-window-up-or-column-left;
                  "Mod+J".action = focus-workspace-down;
                  "Mod+K".action = focus-workspace-up;
                  "Mod+L".action = focus-window-down-or-column-right;

                  "Mod+Shift+H".action = move-column-left;
                  "Mod+Shift+J".action = move-column-to-workspace-down;
                  "Mod+Shift+K".action = move-column-to-workspace-up;
                  "Mod+Shift+L".action = move-column-right;

                  "Mod+Ctrl+H".action = focus-monitor-left;
                  "Mod+Ctrl+J".action = focus-monitor-down;
                  "Mod+Ctrl+K".action = focus-monitor-up;
                  "Mod+Ctrl+L".action = focus-monitor-right;

                  "Mod+Shift+Ctrl+H".action = move-column-to-monitor-left;
                  "Mod+Shift+Ctrl+J".action = move-column-to-monitor-down;
                  "Mod+Shift+Ctrl+K".action = move-column-to-monitor-up;
                  "Mod+Shift+Ctrl+L".action = move-column-to-monitor-right;
                }
              ]
            )
          ]
        );

      overview = {
        zoom = 0.25;
        # NOTE: Wallpaper in the overview backdrop is handled via layer rule below
        # backdrop-color = "#222222";
      };
      layer-rules = [
        {
          matches = [
            {
              namespace = "^noctalia-overview-";
            }
          ];
          place-within-backdrop = true;
        }
        {
          matches = [
            {
              namespace = "^noctalia-wallpaper-";
            }
          ];
          place-within-backdrop = false;
        }
      ];
      layout = {
        border = {
          enable = true;
          width = 1;
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

        gaps = 10;

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
      window-rules =
        let
          mkMatchRule =
            {
              appId,
              title ? "",
              openFloating ? false,
            }:
            let
              baseRule = {
                matches = [
                  {
                    app-id = appId;
                    inherit title;
                  }
                ];
              };
              floatingRule = if openFloating then { open-floating = true; } else { };
            in
            baseRule // floatingRule;

          openFloatingApps =
            builtins.map
              (
                appId:
                mkMatchRule {
                  appId = appId;
                  openFloating = true;
                }
              )
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

          floatingRules = openFloatingApps ++ [ ];

          windowRules = [
            # Float is Baba
            {
              matches = [
                { is-floating = true; }
              ];
              baba-is-float = true;
            }

            # Rounded corners
            {
              geometry-corner-radius =
                let
                  corners = [
                    "bottom-left"
                    "bottom-right"
                    "top-left"
                    "top-right"
                  ];
                  radius = 10.0;
                in
                lib.genAttrs corners (lib.const radius);
              clip-to-geometry = true;
              draw-border-with-background = false;
            }

            # NOTE: Ghostty with blur is handled via raw KDL in
            #       programs.niri.config below (requires niri >= 4a7e443,
            #       not yet in niri-flake's settings schema)

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
        in
        windowRules ++ floatingRules;
      # TODO: <https://github.com/YaLTeR/niri/wiki/Configuration:-Named-Workspaces>
      workspaces = {
        # "main" = {
        #   open-on-output = "eDP-1"; # "DP-3" (external)
        # };
      };
      outputs = {
        "eDP-1" = {
          enable = true;
          mode = {
            width = 2560;
            height = 1600;
          };
          position = {
            x = 0;
            y = 0;
          };
          scale = 1.25;
          variable-refresh-rate = true;
        };
      };
      input = {
        focus-follows-mouse = {
          enable = true;
          max-scroll-amount = "0%";
        };
        warp-mouse-to-focus = {
          enable = false;
        };
        keyboard = {
          repeat-delay = 200;
          repeat-rate = 50;
          track-layout = "global";
          # NOTE: using `fcitx5` `mozc`
          xkb = {
            layout = "us,bg";
            variant = ",phonetic";
            # NOTE: no longer using right shift for Wezterm zooming,
            #       thus no need for `l` only modifiers
            options =
              let
                side = "";
              in
              "grp:${side}alt_${side}shift_toggle";
          };
        };
        mouse = {
          enable = true;
          accel-profile = null;
        };
        touchpad = {
          click-method = "clickfinger";
          dwt = false;
          natural-scroll = true;
          scroll-method = "two-finger";
          tap = false;
        };
      };
      cursor = {
        size = 48;
        hide-when-typing = true;
        hide-after-inactive-ms = 5000;
      };
      animations.window-resize = {
        custom-shader = builtins.readFile ./resize.glsl;
      };
    };
  };
}
