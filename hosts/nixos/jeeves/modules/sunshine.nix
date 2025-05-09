{ config, pkgs, lib, ... }:

let
  # NOTE: GPU and display configuration
  #
  # card0 / renderD129 = iGPU (AMD Raphael integrated)
  # card1 / renderD128 = dGPU (AMD RX 7900 XTX) with DP-1, DP-2, DP-3, HDMI-A-1
  #
  # We use EDID firmware injection on an unused port of the dGPU to create
  # a virtual display that the real GPU can render to with full acceleration.
  gpuCards = {
    igpu = {
      card = "card0";
      render = "renderD129";
    };
    dgpu = {
      card = "card1";
      render = "renderD128";
    };
  };

  # The unused port on the dGPU we'll use for virtual display
  # Using DP-3 so DP-1 and HDMI-A-1 remain available for real monitors
  virtualDisplayPort = "DP-3";

  # Static paths for niri state
  # NOTE: niri doesn't support custom socket paths - it uses niri.{wayland-N}.{PID}.sock
  # We create a symlink to the dynamic socket after niri starts
  sunshineNiriDir = "/var/lib/sunshine-niri";
  niriSocket = "${sunshineNiriDir}/niri.sock";

  # EDID file for virtual display (1080p 60Hz)
  edid1080p = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/akatrevorjay/edid-generator/master/1920x1080.bin";
    hash = "sha256-vMG3e1FFSVChV2zuIw2Yur7K1OjMOliEmeIK3DpsR/Q=";
  };

  # Niri config for persistent session with named workspaces
  niriConfig = pkgs.writeText "niri-sunshine.kdl" /* kdl */ ''
    debug {
      // Force rendering on the dGPU
      render-drm-device "/dev/dri/${gpuCards.dgpu.render}"
      // Ignore the iGPU
      ignore-drm-device "/dev/dri/${gpuCards.igpu.render}"
      // Enable overlay planes for better performance
      enable-overlay-planes
    }

    // Disable physical outputs so niri only uses the virtual display DP-3
    // NOTE: This prevents fbcon from using DP-1 while niri is running
    output "DP-1" {
      off
    }
    output "DP-2" {
      off
    }
    output "HDMI-A-1" {
      off
    }

    // Named workspaces
    workspace "desktop" {
      open-on-output "${virtualDisplayPort}"
    }
    workspace "steam" {
      open-on-output "${virtualDisplayPort}"
    }

    // Window rule: gamescope (Steam Big Picture) always goes to "steam" workspace
    window-rule {
      match app-id="gamescope"
      open-on-workspace "steam"
      open-maximized true
    }

    // Spawn foot on desktop workspace at startup
    spawn-at-startup "${lib.getExe pkgs.foot}"

    // Spawn gamescope+steam on steam workspace at startup
    spawn-at-startup "${lib.getExe pkgs.gamescope}" "--backend" "wayland" "-W" "1920" "-H" "1080" "-r" "144" "-f" "--" "${lib.getExe config.programs.steam.package}" "-tenfoot"
  '';

  # Helper to run niri msg with the static socket symlink
  niriMsg = pkgs.writeShellScript "niri-msg" ''
    if [ -S ${niriSocket} ]; then
      NIRI_SOCKET="${niriSocket}" ${lib.getExe pkgs.niri} msg "$@"
    else
      echo "niri socket not found at ${niriSocket}" >&2
      exit 1
    fi
  '';
in
{
  # NOTE: EDID firmware injection for virtual display on dGPU
  #
  # This makes the GPU think a 1080p monitor is connected to DP-3,
  # allowing GPU-accelerated rendering without a physical display.

  boot.kernelParams = [
    # Load custom EDID for the virtual display port
    "drm.edid_firmware=${virtualDisplayPort}:edid/sunshine-1080p.bin"
    # Enable the display (the 'e' suffix means "enable")
    "video=${virtualDisplayPort}:1920x1080@60e"
  ];

  # EDID firmware package for both runtime and initramfs
  # Using a derivation that copies the file so it can be included in initrd
  hardware.firmware = let
    edidFirmware = pkgs.runCommand "sunshine-edid-firmware" {} ''
      mkdir -p $out/lib/firmware/edid
      cp ${edid1080p} $out/lib/firmware/edid/sunshine-1080p.bin
    '';
  in [ edidFirmware ];

  # Include EDID firmware in initramfs so it's available during early boot
  # This is critical - without this, the kernel can't find the EDID when
  # amdgpu initializes, potentially causing display initialization to fail
  boot.initrd = {
    availableKernelModules = [ "drm" "amdgpu" ];
    # Prepend a cpio archive containing the EDID firmware
    prepend = [
      "${pkgs.runCommand "edid-initrd" {} ''
        mkdir -p lib/firmware/edid
        cp ${edid1080p} lib/firmware/edid/sunshine-1080p.bin
        find lib -print0 | ${lib.getExe pkgs.cpio} -o -H newc --null --quiet | ${lib.getExe pkgs.zstd} -19 > $out
      ''}"
    ];
  };

  # NOTE: Base `sunshine` service configuration

  services.sunshine = {
    enable = true;
    autoStart = true;
    openFirewall = true;
    capSysAdmin = true;  # Required for KMS capture
    settings = {
      # HACK: Default is `47989`, which `+21` (done by the `sunshine` module) overlaps with `OpenCloud`'s `48010`
      port = 47689;
      # KMS capture from the virtual display on the real GPU
      capture = "kms";
      # adapter_name is for VAAPI encoding
      adapter_name = "/dev/dri/${gpuCards.dgpu.render}";
      # NOTE: output_name is NOT set - Sunshine auto-selects the first available
      # display which will be DP-3 (connector 110) since it's the only virtual display
    };
    applications = {
      env = {
        PATH = "$(PATH):$(HOME)/.local/bin";
        # Tell wlroots-based compositors (cage) to use the dGPU
        WLR_DRM_DEVICES = "/dev/dri/${gpuCards.dgpu.card}";
        # Use seatd for seat management (required for headless SSH launch)
        LIBSEAT_BACKEND = "seatd";
        # Only use the virtual display (DP-3), not the physical one
        WLR_DRM_CONNECTORS = virtualDisplayPort;
        # Expose niri socket for IPC commands (e.g., `niri msg`)
        NIRI_SOCKET = niriSocket;
      };
      apps = [
        {
          name = "Steam Big Picture";
          image-path = "steam.png";
          prep-cmd = [
            {
              do = "${niriMsg} action focus-workspace steam";
              undo = "${niriMsg} action focus-workspace desktop";
            }
          ];
        }
        {
          name = "Desktop";
          image-path = "desktop.png";
          prep-cmd = [
            {
              do = "${niriMsg} action focus-workspace desktop";
              undo = "";
            }
          ];
        }
      ];
    };
  };

  # NOTE: Virtual Input Devices configuration

  boot.kernelModules = [
    "uhid"
    "uinput"
  ];

  hardware.uinput.enable = true;

  services.udev.extraRules = lib.concatStringsSep "\n" [
    # NOTE: As noted in <https://myme.no/posts/2025-12-11-hifi-sunshine-on-nixos.html>
    ''KERNEL=="uhid",   MODE="0660", GROUP="input"''
    ''KERNEL=="uinput", MODE="0660", GROUP="input", SYMLINK+="uinput"''
  ];

  users.users.jeeves = {
    extraGroups = [
      "input"
      "uinput"
      "video"
      "render"
      "tty"      # Required for libseat/VT access
      "seat"     # Required for seatd
    ];
    packages = [
      pkgs.niri  # For `niri msg` IPC commands
    ];
  };

  # Enable seatd for seat management (required for headless compositor launch via SSH)
  services.seatd = {
    enable = true;
    user = "jeeves";
  };
  
  # Keep getty on tty1 and tty2 for console access
  # Disable getty on tty3 so niri can use it via seatd
  systemd.services."getty@tty3".enable = false;
  systemd.services."autovt@tty3".enable = false;
  
  # Unbind fbcon from the dGPU so compositors can acquire DRM master
  # Without this, fbcon holds the framebuffer and blocks other DRM clients
  systemd.services.unbind-fbcon = {
    description = "Unbind fbcon to allow headless compositors";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-vconsole-setup.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe pkgs.bash} -c 'echo 0 > /sys/class/vtconsole/vtcon1/bind || true'";
    };
  };

  # NOTE: Augmentation of the `sunshine` user service (generated by the module)

  systemd.user.services.sunshine = {
    serviceConfig = {
      PrivateDevices = false;
    };
  };

  # NOTE: Persistent niri session for Sunshine streaming
  # Starts automatically with sunshine and provides workspaces for Steam and Desktop

  # Ensure state directory exists
  systemd.tmpfiles.settings."sunshine-niri" = {
    "${sunshineNiriDir}".d = {
      user = "jeeves";
      group = "users";
      mode = "0755";
    };
  };

  systemd.user.services.sunshine-niri = {
    description = "Niri compositor for Sunshine streaming";
    wantedBy = [ "sunshine.service" ];
    after = [ "sunshine.service" ];

    environment = {
      WLR_DRM_DEVICES = "/dev/dri/${gpuCards.dgpu.card}";
      LIBSEAT_BACKEND = "seatd";
      WLR_DRM_CONNECTORS = virtualDisplayPort;
      # NOTE: Use VT3 so tty1/tty2 remain available for console
      XDG_VTNR = "3";
    };

    serviceConfig = {
      Type = "simple";
      ExecStartPre = "${lib.getExe pkgs.bash} -c 'echo 0 | sudo tee /sys/class/vtconsole/vtcon1/bind > /dev/null || true'";
      ExecStart = "${lib.getExe pkgs.niri} -c ${niriConfig}";
      ExecStartPost = pkgs.writeShellScript "niri-save-socket" ''
        # Wait for niri to create socket
        sleep 2
        SOCKET=$(ls /run/user/$(id -u)/niri.*.sock 2>/dev/null | head -1)
        if [ -n "$SOCKET" ]; then
          unlink ${niriSocket} 2>/dev/null || true
          ln -s "$SOCKET" ${niriSocket}
        fi
      '';
      ExecStopPost = pkgs.writeShellScript "niri-cleanup" ''
        unlink ${niriSocket} 2>/dev/null || true
        # Rebind fbcon to restore console on DP-1 (unbind then bind to re-initialize)
        echo 0 | sudo tee /sys/class/vtconsole/vtcon1/bind > /dev/null || true
        sleep 0.5
        echo 1 | sudo tee /sys/class/vtconsole/vtcon1/bind > /dev/null || true
      '';
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # NOTE: Virtual host for the Web UI of `sunshine`

  services.nginx = {
    virtualHosts."sunshine.jeeves.reo101.xyz" = {
      forceSSL = true;
      useACMEHost = "jeeves.reo101.xyz";
      locations."/" = {
        proxyPass = "https://127.0.0.1:${builtins.toString (config.services.sunshine.settings.port + 1)}";
        proxyWebsockets = true;
        extraConfig = /* nginx */ ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };
}
