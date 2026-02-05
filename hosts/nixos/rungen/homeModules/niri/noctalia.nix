{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;
    settings = {
      bar = {
        showCapsule = true;
        density = "compact";
        exclusive = true;
        floating = false;
        position = "right";
        outerCorners = true;
        showOutline = false;
        transparent = false;
        marginHorizontal = 0.25;
        marginVertical = 0.25;
        widgets = {
          left = [
            {
              id = "ControlCenter";
              useDistroLogo = true;
              colorizeDistroLogo = true;
            }
            # {
            #   id = "WiFi";
            # }
            {
              id = "Bluetooth";
            }
          ];
          center = [
            {
              id = "Workspace";
              hideUnoccupied = false;
              labelMode = "none";
            }
          ];
          right = [
            {
              id = "Battery";
              displayMode = "alwaysShow";
              warningThreshold = 30;
            }
            {
              formatHorizontal = "HH:mm";
              formatVertical = "HH mm";
              id = "Clock";
              useMonospacedFont = true;
              usePrimaryColor = true;
            }
          ];
        };
      };
      brightness = {
        brightnessStep = 5;
        enableDdcSupport = true;
        enforceMinimum = true;
      };
      general = {
        avatarImage = pkgs.fetchurl {
          url = "https://github.com/${config.home.username}.png";
          hash = "sha256-4OILsWeqJjMLLYQsraGNX+hcpfgXdbJ9RPyiKfW3DG0=";
        };
        radiusRatio = 0.5;
        lockOnSuspend = true;
        showHibernateOnLockScreen = true;
        showSessionButtonsOnLockScreen = true;
        showScreenCorners = false;
      };
      dock = {
        enabled = false;
      };
      hooks = {
        enabled = true;
        darkModeChange = /* bash */ "";
        performanceModeDisabled = /* bash */ "";
        performanceModeEnabled = /* bash */ "";
        screenLock = /* bash */ "";
        screenUnlock = /* bash */ "";
        wallpaperChange = /* bash */ "";
      };
      location = {
        weatherEnabled = true;
        name = "Sofia, Bulgaria";
        monthBeforeDay = true;
        firstDayOfWeek = 0;
        showWeekNumberInCalendar = true;
        weatherShowEffects = true;
      };
      # TODO: `iwd` support
      network = {
        wifiEnabled = false;
      };
      nightLight = {
        enabled = false;
        autoSchedule = true;
        dayTemp = "6500";
        nightTemp = "4000";
      };
      notifications = {
        enabled = true;
        location = "top_right";
        respectExpireTimeout = true;
      };
      appLauncher = {
        enableClipPreview = true;
        enableClipboardHistory = true;
        customLaunchPrefixEnabled = false;
        customLaunchPrefix = "";
        viewMode = "grid";
        terminalCommand = "${lib.getExe pkgs.ghostty} -e";
      };
      audio = {
        externalMixer = "${lib.getExe pkgs.pavucontrol}";
      };
      wallpaper = {
        enabled = true;
        directory = "${config.xdg.dataHome}/wallpapers";
        viewMode = "recursive";
        setWallpaperOnAllMonitors = true;
        overviewEnabled = true;
        overviewBlur = 0.4;
        overviewTint = 0.6;
      };
      settingsVersion = 33;
    };
  };
}
