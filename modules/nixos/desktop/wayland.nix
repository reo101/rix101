{ inputs, config, lib, pkgs, ... }:

let
  cfg = config.reo101.wayland;
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
  in {
    reo101.wayland = {
      # TODO: better naming
      enable = lib.mkEnableOption "reo101 Wayland config";

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
            throw "`reo101.wayland.user` must be set explicitly when home-manager user count is not exactly one (found ${builtins.toString hmUserCount})";
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
            falling back to `reo101.wayland.niri.package`
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
          type = types.nullOr (types.submodule {
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
          });
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
    in
    {
      assertions = [
        {
          assertion = hasImage != hasColorscheme;
          message = "Exactly one of `reo101.wayland.stylix.image` or `reo101.wayland.stylix.colorscheme` must be set when `reo101.wayland.enable = true`";
        }
        {
          assertion = cfg.niri.homeManagerModule != null -> hasHomeManager;
          message = "`reo101.wayland.niri.homeManagerModule` requires importing the Home Manager NixOS module";
        }
      ];

      stylix =
        {
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

      home-manager.users = lib.mkIf (cfg.niri.homeManagerModule != null && hasHomeManager) {
        "${cfg.user}" = {
          imports = [ cfg.niri.homeManagerModule ];
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
        extraPortals = lib.mkDefault [ pkgs.xdg-desktop-portal-gnome ];
        config.common = {
          default = lib.mkDefault [ "wlr" ];
          "org.freedesktop.impl.portal.FileChooser" = lib.mkDefault [ "gnome" ];
          "org.freedesktop.impl.portal.ScreenCast" = lib.mkDefault [ "gnome" ];
          "org.freedesktop.impl.portal.RemoteDesktop" = lib.mkDefault [ "gnome" ];
        };
      };

      environment.systemPackages = [
        niriSessionPackage
        pkgs.wl-clipboard
        pkgs.wlr-randr
        pkgs.grim
        pkgs.slurp
      ];

      # Sound
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
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
