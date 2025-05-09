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

  # Virtual display configurations
  # For non-standard aspect ratios, specify `ratio` (e.g., "16:9") to avoid EDID generation failure
  virtualDisplays = [
    {
      width = 1920;
      height = 1080;
      refresh = 60;
    }
    {
      name = "cheetah";
      width = 3120;
      height = 1440;
      refresh = 120;
    }
  ];

  # Generate EDID name from display config (max 12 chars for EDID compatibility)
  mkEdidName = d: let name = d.name or "${builtins.toString d.height}p";
    in assert (builtins.stringLength name) <= 12; name;

  # Generate EDID binaries using edid-generator with cvt-generated modelines
  generatedEdids = pkgs.edid-generator.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.libxcvt ];
    clean = true;
    passAsFile = [ ];
    modelines = null;
    # Skip validation for non-standard aspect ratios
    doCheck = false;

    # Patch modeline2edid to use closest ratio instead of failing on unknown
    postPatch = (old.postPatch or "") + /* bash */ ''
      substituteInPlace modeline2edid \
        --replace-fail "[[ \$ratio != 'UNKNOWN' ]] || return 1" \
                       ": # Allow unknown ratios - will use closest match"
      # Change default from 'UNKNOWN' to '16:9' (most common for modern displays)
      substituteInPlace modeline2edid \
        --replace-fail "find-supported-ratio \$hdisp \$vdisp 'UNKNOWN'" \
                       "find-supported-ratio \$hdisp \$vdisp '16:9'"
    '';

    preConfigure = ''
      # Generate modeline from width, height, refresh, name, and optional ratio
      gen_modeline() {
        local width="$1" height="$2" refresh="$3" name="$4" ratio="$5"
        local modeline
        modeline=$(cvt "$width" "$height" "$refresh" | grep Modeline | sed 's/"[^"]*"/"'"$name"'/')
        # Append ratio override if provided
        [[ -n "$ratio" ]] && modeline="$modeline ratio=$ratio"
        echo "$modeline"
      }

      # Generate modelines for all virtual displays
      {
        ${lib.concatMapStringsSep "\n" (
          { width
          , height
          , refresh ? "60"
          , ratio ? "16:9"
          , name ? "${builtins.toString height}p"
          }: /* bash */ ''
            gen_modeline ${lib.escapeShellArgs [width height refresh name ratio]}
          ''
        ) virtualDisplays}
      } > "$NIX_BUILD_TOP/modelines"
      export modelinesPath="$NIX_BUILD_TOP/modelines"
    '';
  });

  # Primary virtual display (first in list)
  virtualDisplay = builtins.head virtualDisplays;
  edidName = mkEdidName virtualDisplay;

  # Static paths for niri state
  # NOTE: niri doesn't support custom socket paths - it uses niri.{wayland-N}.{PID}.sock
  # We create a symlink to the dynamic socket after niri starts
  sunshineNiriDir = "/var/lib/sunshine-niri";
  niriSocket = "${sunshineNiriDir}/niri.sock";

  # Niri config for persistent session with named workspaces
  niriConfig = pkgs.writeText "niri-sunshine.kdl" /* kdl */ ''
    debug {
      // Force rendering on the dGPU
      render-drm-device "/dev/dri/${gpuCards.dgpu.render}"
      // Ignore the iGPU
      ignore-drm-device "/dev/dri/${gpuCards.igpu.render}"
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

    // Named workspaces (steam first = top row)
    workspace "steam" {
      open-on-output "${virtualDisplayPort}"
    }
    workspace "desktop" {
      open-on-output "${virtualDisplayPort}"
    }

    // Window rule: gamescope (Steam Big Picture) always goes to "steam" workspace
    window-rule {
      match app-id="gamescope"
      open-on-workspace "steam"
      open-maximized true
    }

    // Keybinds (Alt as modifier)
    binds {
      Alt+Return { spawn "${lib.getExe pkgs.ghostty}"; }
      Alt+Up { toggle-overview; }
    }

    // Spawn foot on desktop workspace at startup
    spawn-at-startup "${lib.getExe pkgs.foot}"

    // Spawn gamescope+steam on steam workspace at startup
    // --steam enables Steam integration for controller passthrough
    spawn-at-startup "${lib.getExe pkgs.gamescope}" "--backend" "wayland" "--output-width" "1920" "--output-height" "1080" "--nested-refresh" "144" "--fullscreen" "--steam" "--" "${lib.getExe config.programs.steam.package}" "-tenfoot"
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
  # Uses pkgs.edid-generator to create the EDID from a modeline.

  hardware.display = {
    edid.packages = [ generatedEdids ];

    outputs.${virtualDisplayPort} = {
      edid = "${edidName}.bin";
      # Enable the display
      mode = "e";
    };
  };

  # Include EDID firmware in initramfs so it's available during early boot
  # This is critical - without this, the kernel can't find the EDID when
  # amdgpu initializes, potentially causing display initialization to fail
  boot.initrd.availableKernelModules = [ "drm" "amdgpu" ];

  # NOTE: Base `sunshine` service configuration

  services.sunshine = {
    enable = true;
    autoStart = true;
    openFirewall = true;
    capSysAdmin = true;  # Required for KMS capture
    settings = {
      # WARN: Default is `47989`, which `+21` (done by the `sunshine` module) overlaps with `OpenCloud`'s `48010`
      port = 47989;
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
      ExecStartPre = "${lib.getExe pkgs.bash} -c 'echo 0 | /run/wrappers/bin/sudo tee /sys/class/vtconsole/vtcon1/bind > /dev/null || true'";
      ExecStart = "${lib.getExe pkgs.niri} -c ${niriConfig}";
      ExecStartPost = pkgs.writeShellScript "niri-save-socket" ''
        # Wait for niri to create socket (poll up to 10 seconds)
        for i in $(seq 1 20); do
          SOCKET=$(ls /run/user/$(id -u)/niri.*.sock 2>/dev/null | head -1)
          [ -n "$SOCKET" ] && break
          sleep 0.5
        done
        if [ -n "$SOCKET" ]; then
          unlink ${niriSocket} 2>/dev/null || true
          ln -s "$SOCKET" ${niriSocket}
        fi
      '';
      ExecStopPost = pkgs.writeShellScript "niri-cleanup" ''
        unlink ${niriSocket} 2>/dev/null || true
        # Rebind fbcon to restore console on DP-1 (unbind then bind to re-initialize)
        echo 0 | /run/wrappers/bin/sudo tee /sys/class/vtconsole/vtcon1/bind > /dev/null || true
        sleep 0.5
        echo 1 | /run/wrappers/bin/sudo tee /sys/class/vtconsole/vtcon1/bind > /dev/null || true
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
