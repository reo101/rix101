{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.rix101.wayland;
  easyeffectsEchoProbePackage =
    pkgs.runCommandLocal "wireplumber-easyeffects-echo-probe"
      {
        nativeBuildInputs = [ pkgs.custom.fennel ];
      }
      ''
        mkdir -p "$out/share/wireplumber/scripts/reo101"
        ${lib.getExe' pkgs.custom.fennel "fennel"} \
          --correlate \
          --compile ${./easyeffects-echo-probe.fnl} \
          > "$out/share/wireplumber/scripts/reo101/easyeffects-echo-probe.lua"
      '';
in
{
  imports = [
    # NOTE: using the `home-manager` module manually, still
    # inputs.niri.nixosModules.niri
    inputs.stylix.nixosModules.stylix
  ];

  options =
    let
      inherit (lib) types;
    in
    {
      rix101.wayland = {
        # TODO: better naming
        enable = lib.mkEnableOption "rix101 Wayland config";

        user = lib.mkOption {
          type = types.str;
          default =
            let
              hmUsers = builtins.attrNames (lib.attrByPath [ "home-manager" "users" ] { } config);
              hmUserCount = builtins.length hmUsers;
            in
            if hmUserCount == 1 then
              builtins.head hmUsers
            else
              throw "`rix101.wayland.user` must be set explicitly when home-manager user count is not exactly one (found ${builtins.toString hmUserCount})";
          description = "Primary desktop user used by `greetd` and Home Manager lookups";
        };

        niri = {
          package = lib.mkOption {
            type = types.package;
            description = "Fallback package used for the `niri` session binary";
            default = pkgs.niri;
            defaultText = lib.literalExpression "pkgs.niri";
          };
          sessionBinary = lib.mkOption {
            type = types.str;
            description = "Binary used by greetd to start the `niri` session";
            default = "niri-session";
          };
          preferHomeManagerPackage = lib.mkOption {
            type = types.bool;
            description = ''
              Prefer `config.home-manager.users.<user>.programs.niri.package` when available,
              falling back to `rix101.wayland.niri.package`
            '';
            default = true;
          };
          homeManagerModule = lib.mkOption {
            type = types.nullOr types.deferredModule;
            description = ''
              Optional Home Manager module imported into `home-manager.users.<user>.imports`.
              Keep this unset to manage Niri Home Manager configuration directly in host/user modules.
            '';
            default = null;
          };
        };

        river = {
          enable = lib.mkEnableOption "`river-classic` compositor support";
          package = lib.mkOption {
            type = types.package;
            description = "Package used for `programs.river-classic` when enabled";
            default = pkgs.river-classic;
            defaultText = lib.literalExpression "pkgs.river-classic";
          };
        };

        lock = {
          command = lib.mkOption {
            type = types.listOf types.str;
            description = ''
              Command vector used by compositor/user keybinds to lock the current session.
              This keeps lock behavior host-specific without hard-coding lock tools in Home Manager modules.
            '';
            default = [
              (lib.getExe' pkgs.systemd "loginctl")
              "lock-session"
            ];
            defaultText = lib.literalExpression ''
              [
                (lib.getExe' pkgs.systemd "loginctl")
                "lock-session"
              ]
            '';
            example = lib.literalExpression ''
              [ "noctalia-shell" "ipc" "call" "lockScreen" "lock" ]
            '';
          };
        };

        portal = {
          desktopNames = lib.mkOption {
            type = types.listOf types.str;
            description = ''
              Desktop names used for desktop-specific portal preference files.
              `xdg-desktop-portal` resolves preferences from `''${desktop}-portals.conf`
              based on `XDG_CURRENT_DESKTOP`, so list your session desktops here
              (for example `[ "niri" ]`).
            '';
            default = [ ];
            example = [ "niri" ];
          };

          fileChooserBackend = lib.mkOption {
            type = types.enum [
              "gnome"
              "gtk"
              "portty"
            ];
            description = ''
              XDG desktop portal backend used for the FileChooser interface.
              Use `gtk` to avoid depending on Nautilus/GNOME Files startup for file picking,
              or `portty` for a terminal-driven picker workflow.
            '';
            default = "gnome";
            example = "portty";
          };

          portty = {
            package = lib.mkOption {
              type = types.package;
              description = "Package providing `portty` and `porttyd` binaries";
              default = pkgs.custom.portty;
              defaultText = lib.literalExpression "pkgs.custom.portty";
            };

            useInDesktops = lib.mkOption {
              type = types.listOf types.str;
              description = ''
                Extra desktop names appended to Portty's `UseIn=` portal metadata.
                Keep package-level metadata generic and define host/session policy here
                (for example `[ "niri" ]`).
              '';
              default = [ ];
              example = [ "niri" ];
            };

            configText = lib.mkOption {
              type = types.lines;
              description = ''
                Contents of `~/.config/portty/config.toml`.
                This defines terminal command and helper shims used by `portty` sessions.
              '';
              default = ''
                exec = "@PORTTY_TERMINAL@"

                [file-chooser]
                exec = "@PORTTY_TERMINAL@"

                [file-chooser.bin]
                pick = "${lib.getExe pkgs.fd} --type f --type d --hidden --exclude .git . | ${lib.getExe pkgs.fzf} --multi --height=100% --reverse --prompt='pick> ' | @PORTTY_SEL@ --stdin"
              '';
            };
          };
        };

        stylix = {
          image = lib.mkOption {
            type = types.nullOr types.path;
            description = "Wallpaper image passed to `stylix`";
            default = null;
          };
          colorscheme = lib.mkOption {
            type = types.nullOr types.anything;
            description = "`base16` colorscheme passed to `stylix.base16Scheme`";
            default = null;
          };
          cursor = lib.mkOption {
            type = types.nullOr (
              types.submodule {
                options = {
                  name = lib.mkOption {
                    type = types.str;
                    description = "Cursor theme name";
                  };
                  package = lib.mkOption {
                    type = types.package;
                    description = "Cursor theme package";
                  };
                  size = lib.mkOption {
                    type = types.ints.positive;
                    description = "Cursor size";
                    default = 24;
                  };
                };
              }
            );
            description = "Optional Stylix cursor configuration";
            default = null;
          };
          fonts = {
            monospace = {
              package = lib.mkOption {
                type = types.package;
                description = "Monospace font package used by Stylix";
                default = pkgs.jetbrains-mono;
                defaultText = lib.literalExpression "pkgs.jetbrains-mono";
              };
              name = lib.mkOption {
                type = types.str;
                description = "Monospace font family name used by Stylix";
                default = "JetBrains Mono";
              };
            };
            serif = {
              package = lib.mkOption {
                type = types.package;
                description = "Serif font package used by Stylix";
                default = pkgs.noto-fonts;
                defaultText = lib.literalExpression "pkgs.noto-fonts";
              };
              name = lib.mkOption {
                type = types.str;
                description = "Serif font family name used by Stylix";
                default = "Noto Serif";
              };
            };
            sansSerif = {
              package = lib.mkOption {
                type = types.package;
                description = "Sans-serif font package used by Stylix";
                default = pkgs.noto-fonts;
                defaultText = lib.literalExpression "pkgs.noto-fonts";
              };
              name = lib.mkOption {
                type = types.str;
                description = "Sans-serif font family name used by Stylix";
                default = "Noto Sans";
              };
            };
            emoji = {
              package = lib.mkOption {
                type = types.package;
                description = "Emoji font package used by Stylix";
                default = pkgs.noto-fonts-color-emoji;
                defaultText = lib.literalExpression "pkgs.noto-fonts-color-emoji";
              };
              name = lib.mkOption {
                type = types.str;
                description = "Emoji font family name used by Stylix";
                default = "Noto Color Emoji";
              };
            };
          };
        };

      };
    };

  config = lib.mkIf cfg.enable (
    let
      hasImage = cfg.stylix.image != null;
      hasColorscheme = cfg.stylix.colorscheme != null;
      hasHomeManager = config ? home-manager;
      usePorttyBackend = cfg.portal.fileChooserBackend == "portty";
      portalBackendNameByBackend = {
        gnome = "gnome";
        gtk = "gtk";
        portty = "tty";
      };
      portalDesktopNames = [ "common" ] ++ cfg.portal.desktopNames;
      fileChooserPortalBackendName = portalBackendNameByBackend.${cfg.portal.fileChooserBackend};
      portalPackageByBackend = {
        gnome = pkgs.xdg-desktop-portal-gnome;
        gtk = pkgs.xdg-desktop-portal-gtk;
        portty = porttyPortalPackage;
      };
      fileChooserPortalPackage = portalPackageByBackend.${cfg.portal.fileChooserBackend};
      portalPreferredConfig = {
        default = lib.mkDefault [ "wlr" ];
        "org.freedesktop.impl.portal.FileChooser" = lib.mkDefault [ fileChooserPortalBackendName ];
        "org.freedesktop.impl.portal.ScreenCast" = lib.mkDefault [ "gnome" ];
        "org.freedesktop.impl.portal.RemoteDesktop" = lib.mkDefault [ "gnome" ];
      };
      porttyPortalUseInDesktops = lib.concatStringsSep ";" (
        cfg.portal.portty.useInDesktops ++ cfg.portal.desktopNames
      );
      porttyPortalPackage = pkgs.symlinkJoin {
        name = "portty-with-portal-metadata-${cfg.portal.portty.package.version or "unknown"}";
        paths = [ cfg.portal.portty.package ];
        postBuild = ''
          portal_file="$out/share/xdg-desktop-portal/portals/tty.portal"
          rm -f "$portal_file"
          cp ${cfg.portal.portty.package}/share/xdg-desktop-portal/portals/tty.portal "$portal_file"

          if grep -q '^UseIn=' "$portal_file"; then
            use_in_value="$(sed -n 's/^UseIn=//p' "$portal_file")"
            if [ -n '${porttyPortalUseInDesktops}' ]; then
              use_in_value="$use_in_value;${porttyPortalUseInDesktops}"
            fi

            use_in_value="$(
              printf '%s' "$use_in_value" \
                | tr ';' '\n' \
                | sed '/^$/d' \
                | awk '!seen[$0]++' \
                | paste -sd';' -
            )"
            sed -i "s|^UseIn=.*$|UseIn=$use_in_value|" "$portal_file"
          elif [ -n '${porttyPortalUseInDesktops}' ]; then
            printf 'UseIn=%s\n' '${porttyPortalUseInDesktops}' >> "$portal_file"
          fi
        '';
      };
      hmNiriPackage = lib.attrByPath [
        "home-manager"
        "users"
        cfg.user
        "programs"
        "niri"
        "package"
      ] null config;
      niriSessionPackage =
        if cfg.niri.preferHomeManagerPackage && hmNiriPackage != null then
          hmNiriPackage
        else
          cfg.niri.package;
      hmGhosttyPackage = lib.attrByPath [
        "home-manager"
        "users"
        cfg.user
        "programs"
        "ghostty"
        "package"
      ] null config;
      porttyTerminalExe =
        if hmGhosttyPackage != null then lib.getExe hmGhosttyPackage else lib.getExe pkgs.ghostty;
      porttyHelperPackage = pkgs.callPackage ./wayland-portty-helper {
        portty = cfg.portal.portty.package;
        inherit (pkgs) zenity;
      };
    in
    {
      assertions = [
        {
          assertion = hasImage != hasColorscheme;
          message = "Exactly one of `rix101.wayland.stylix.image` or `rix101.wayland.stylix.colorscheme` must be set when `rix101.wayland.enable = true`";
        }
        {
          assertion = cfg.niri.homeManagerModule != null -> hasHomeManager;
          message = "`rix101.wayland.niri.homeManagerModule` requires importing the Home Manager NixOS module";
        }
        {
          assertion = usePorttyBackend -> hasHomeManager;
          message = "`rix101.wayland.portal.fileChooserBackend = \"portty\"` requires importing the Home Manager NixOS module";
        }
        {
          assertion = usePorttyBackend -> (hmGhosttyPackage != null || pkgs ? ghostty);
          message = "`rix101.wayland.portal.fileChooserBackend = \"portty\"` requires `programs.ghostty.package` in Home Manager or `pkgs.ghostty`";
        }
      ];

      stylix = {
        enable = true;
        fonts = {
          monospace = {
            inherit (cfg.stylix.fonts.monospace) package name;
          };
          serif = {
            inherit (cfg.stylix.fonts.serif) package name;
          };
          sansSerif = {
            inherit (cfg.stylix.fonts.sansSerif) package name;
          };
          emoji = {
            inherit (cfg.stylix.fonts.emoji) package name;
          };
        };
      }
      // lib.optionalAttrs hasImage {
        image = cfg.stylix.image;
      }
      // lib.optionalAttrs hasColorscheme {
        base16Scheme = cfg.stylix.colorscheme;
      }
      // lib.optionalAttrs (cfg.stylix.cursor != null) {
        cursor = cfg.stylix.cursor;
      };

      fonts.packages = lib.unique [
        pkgs.noto-fonts
        pkgs.noto-fonts-cjk-sans
        cfg.stylix.fonts.monospace.package
        cfg.stylix.fonts.serif.package
        cfg.stylix.fonts.sansSerif.package
        cfg.stylix.fonts.emoji.package
      ];

      environment.sessionVariables = {
        # Hint Electron apps to use Wayland.
        NIXOS_OZONE_WL = lib.mkDefault "1";
        MOZ_ENABLE_WAYLAND = lib.mkDefault "1";
        QT_WAYLAND_DISABLE_WINDOWDECORATION = lib.mkDefault "1";
      };

      services.greetd = {
        enable = true;
        settings = {
          terminal = {
            vt = 1;
          };
          default_session = {
            inherit (cfg) user;
            command = "${lib.getExe pkgs.tuigreet} --cmd ${lib.getExe' niriSessionPackage cfg.niri.sessionBinary}";
          };
        };
      };

      home-manager.users = lib.mkIf hasHomeManager {
        "${cfg.user}" =
          {
            config,
            lib,
            ...
          }:
          {
            imports = lib.optional (cfg.niri.homeManagerModule != null) cfg.niri.homeManagerModule;

            # NOTE: Previously was the default
            gtk.gtk4.theme = lib.mkDefault config.gtk.theme;

            # Some sessions export `NIX_XDG_DESKTOP_PORTAL_DIR` to the per-user profile.
            # Ensure that profile contains the selected FileChooser backend metadata.
            home.packages = lib.optionals usePorttyBackend [
              fileChooserPortalPackage
              pkgs.xdg-desktop-portal-gnome
              porttyHelperPackage
            ];

            home.sessionPath = lib.optionals usePorttyBackend [
              "${porttyHelperPackage}/bin"
            ];

            xdg.configFile = lib.mkIf usePorttyBackend {
              "portty/config.toml".text =
                lib.replaceStrings
                  [
                    "@PORTTY_TERMINAL@"
                    "@PORTTY_SESSION_HOLDER@"
                    "@PORTTY_SEL@"
                    "@PORTTY_SUBMIT@"
                  ]
                  [
                    porttyTerminalExe
                    (lib.getExe' porttyHelperPackage "portty-session-holder")
                    (lib.getExe' porttyHelperPackage "sel")
                    (lib.getExe' porttyHelperPackage "submit")
                  ]
                  cfg.portal.portty.configText;
            };

            systemd.user.services.portty = lib.mkIf usePorttyBackend {
              Unit = {
                Description = "Portty - XDG Desktop Portal for TTY";
                After = [ "graphical-session.target" ];
              };
              Service = {
                Type = "simple";
                Environment = [
                  "DISPLAY="
                  "GDK_BACKEND=wayland"
                ];
                ExecStart = "${lib.getExe' porttyHelperPackage "porttyd-wayland-wrapper"}";
                Restart = "on-failure";
                RestartSec = 5;
              };
              Install = {
                WantedBy = [
                  "default.target"
                  "graphical-session.target"
                ];
              };
            };
          };
      };

      programs.river-classic = lib.mkIf cfg.river.enable {
        enable = true;
        package = cfg.river.package;
      };

      # XDG portals
      xdg.portal = {
        enable = lib.mkDefault true;
        wlr.enable = lib.mkDefault true;
        extraPortals = lib.mkAfter [
          fileChooserPortalPackage
          pkgs.xdg-desktop-portal-gnome
        ];
        config = lib.genAttrs portalDesktopNames (_: portalPreferredConfig);
      };

      environment.systemPackages = [
        niriSessionPackage
        pkgs.wl-clipboard
        pkgs.wlr-randr
        pkgs.grim
        pkgs.slurp
      ]
      ++ lib.optionals usePorttyBackend [
        cfg.portal.portty.package
        porttyHelperPackage
      ];

      # Sound
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
        wireplumber.enable = true;
        wireplumber.configPackages = [
          easyeffectsEchoProbePackage
        ];
        wireplumber.extraConfig = {
          "51-audio-priority" = {
            "monitor.alsa.rules" = [
              {
                matches = [
                  { "node.name" = "easyeffects_sink"; }
                ];
                actions.update-props = {
                  "priority.driver" = 10;
                  "priority.session" = 10;
                };
              }
              {
                matches = [
                  { "node.name" = "~alsa_output.*"; }
                ];
                actions = {
                  update-props = {
                    "device.profile.switch-on-connect" = false;
                  };
                };
              }
            ];
          };
          "52-bluetooth-properties" = {
            "monitor.bluez.properties" = {
              "bluez5.enable-sbc-xq" = true;
              "bluez5.enable-msbc" = true;
              "bluez5.enable-hw-volume" = true;
              "bluez5.roles" = [
                "a2dp_sink"
                "a2dp_source"
              ];
            };
          };
          "53-easyeffects-echo-probe" = {
            "wireplumber.components" = [
              {
                name = "reo101/easyeffects-echo-probe.lua";
                type = "script/lua";
                provides = "rix101.easyeffects-echo-probe";
              }
            ];
            "wireplumber.profiles" = {
              main = {
                "rix101.easyeffects-echo-probe" = "required";
              };
            };
          };
        };

      };

      # IME
      i18n.inputMethod = {
        enable = true;
        type = "fcitx5";

        fcitx5 = {
          waylandFrontend = true;

          addons = [
            pkgs.fcitx5-mozc
            pkgs.fcitx5-gtk
          ];
        };
      };

      # Input
      services.libinput = {
        enable = true;
        mouse.accelProfile = "flat";
        touchpad.accelProfile = "flat";
      };
    }
  );
}
