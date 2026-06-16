{ lib, pkgs, config, ... }:

let
  sunshineUser = "jeeves";
  sunshineGroup = "users";
  niriTTY = "tty3";
  niriVT = "3";

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
  generatedEdids = lib.infuse pkgs.edid-generator {
    __output.nativeBuildInputs.__append = [ pkgs.libxcvt ];
    __output.clean.__assign = true;
    # Skip validation for non-standard aspect ratios
    __output.doCheck.__assign = false;

    # Patch modeline2edid to use closest ratio instead of failing on unknown
    __output.postPatch.__append = /* bash */ ''
      substituteInPlace modeline2edid \
        --replace-fail "[[ \$ratio != 'UNKNOWN' ]] || return 1" \
                       ": # Allow unknown ratios - will use closest match"
      # Change default from 'UNKNOWN' to '16:9' (most common for modern displays)
      substituteInPlace modeline2edid \
        --replace-fail "find-supported-ratio \$hdisp \$vdisp 'UNKNOWN'" \
                       "find-supported-ratio \$hdisp \$vdisp '16:9'"
    '';

    __output.preConfigure.__assign = ''
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
      export modelines="$(cat "$NIX_BUILD_TOP/modelines")"
    '';
  };

  # Primary virtual display (first in list)
  virtualDisplay = builtins.head virtualDisplays;
  edidName = mkEdidName virtualDisplay;

  # Static paths for niri state
  # NOTE: niri doesn't support custom socket paths - it uses niri.{wayland-N}.{PID}.sock
  # We create a symlink to the dynamic socket after niri starts
  sunshineNiriDir = "/var/lib/sunshine-niri";
  niriSocket = "${sunshineNiriDir}/niri.sock";

  steamBigPicture = pkgs.writeShellScript "steam-big-picture" ''
    exec ${lib.getExe' pkgs.util-linux "setpriv"} --ambient-caps -all --inh-caps -all \
      ${lib.getExe pkgs.gamescope} \
        --backend wayland \
        --output-width 1920 \
        --output-height 1080 \
        --nested-refresh 144 \
        --fullscreen \
        --steam \
        -- ${lib.getExe config.programs.steam.package} -tenfoot
  '';

  # Niri config for persistent session with named workspaces
  niriConfig = pkgs.writeText "niri-sunshine.kdl" /* kdl */ ''
    debug {
      // Force rendering on the dGPU
      render-drm-device "/dev/dri/${gpuCards.dgpu.render}"
      // Ignore the iGPU
      ignore-drm-device "/dev/dri/${gpuCards.igpu.render}"
    }

    // Keep niri off the real monitor; HDMI stays for tty1 on VT1
    output "HDMI-A-1" {
      off
    }
    output "DP-1" {
      off
    }
    output "DP-2" {
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

  niriFocus = pkgs.writeShellScript "niri-focus" ''
    for i in $(seq 1 40); do
      SOCKET=$(ls -t /run/user/$(id -u)/niri.*.sock 2>/dev/null | head -1)
      if [ -n "$SOCKET" ]; then
        ln -sfn "$SOCKET" ${niriSocket}
        ${niriMsg} action focus-workspace "$1" && exit 0
      fi
      sleep 0.25
    done
    exit 1
  '';

  steamStart = pkgs.writeShellScript "steam-start" ''
    ${niriFocus} steam
    if ! ${lib.getExe' pkgs.procps "pgrep"} -u $(id -u) -f 'gamescope.*steam' >/dev/null; then
      ${niriMsg} action spawn -- ${steamBigPicture}
    fi
  '';

  steamStop = pkgs.writeShellScript "steam-stop" ''
    ${niriFocus} desktop || true
    ${lib.getExe' pkgs.procps "pkill"} -TERM -u $(id -u) -f 'gamescope.*steam' || true
  '';
in
{
  # NOTE: EDID firmware injection for virtual display on `dGPU`
  #
  # This makes the GPU think a `1080p` monitor is connected to `DP-3`
  # allowing GPU-accelerated rendering without a physical display
  # Uses `pkgs.edid-generator` to create the EDID from a modeline

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

  system.services."sunshine-wol-restart" = {
    imports = [ pkgs.custom.sunshine-wol-restart.services.default ];
    sunshine-wol-restart = {
      targetMac = config.systemd.network.links."10-eth0".matchConfig.PermanentMACAddress;
      user = sunshineUser;
      restartServices = [ "sunshine.service" ];
    };
  };
  networking.firewall.allowedUDPPorts = [ config.system.services."sunshine-wol-restart".sunshine-wol-restart.port ];

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
      # Sunshine wants the KMS monitor index from its startup log, not the connector name
      output_name = "0";
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
              do = "${steamStart}";
              undo = "${steamStop}";
            }
          ];
        }
        {
          name = "Desktop";
          image-path = "desktop.png";
          prep-cmd = [
            {
              do = "${niriFocus} desktop";
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

  users.users.${sunshineUser} = {
    linger = true;

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
    user = "${sunshineUser}";
  };

  # Keep tty1 for emergency console access; niri uses tty3 only while streaming
  systemd.services."getty@${niriTTY}".enable = false;
  systemd.services."autovt@${niriTTY}".enable = false;

  # NOTE: Augmentation of the `sunshine` user service (generated by the module)

  systemd.user.services.sunshine = {
    serviceConfig = {
      PrivateDevices = false;
      KillSignal = "SIGKILL";
      TimeoutStopSec = "5s";
    };
  };

  # NOTE: Niri session for Sunshine streaming
  # Kept running so Sunshine has a KMS display to capture before app prep runs

  # Ensure state directory exists
  systemd.tmpfiles.settings."sunshine-niri" = {
    "${sunshineNiriDir}".d = {
      user = "${sunshineUser}";
      group = "${sunshineGroup}";
      mode = "0755";
    };
  };

  systemd.services.sunshine-niri = {
    description = "Niri compositor for Sunshine streaming";
    conflicts = [ "getty@${niriTTY}.service" "autovt@${niriTTY}.service" ];
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-user-sessions.service" ];

    environment = {
      XDG_RUNTIME_DIR = "/run/user/%U";
      WLR_DRM_DEVICES = "/dev/dri/${gpuCards.dgpu.card}";
      WLR_DRM_CONNECTORS = virtualDisplayPort;
      XDG_VTNR = niriVT;
    };

    serviceConfig = {
      Type = "simple";
      User = sunshineUser;
      Group = sunshineGroup;
      PAMName = "login";
      WorkingDirectory = "/home/${sunshineUser}";
      TTYPath = "/dev/${niriTTY}";
      TTYReset = true;
      TTYVHangup = true;
      StandardInput = "tty";
      StandardOutput = "journal";
      ExecStart = pkgs.writeShellScript "niri-run" ''
        rm -f /run/user/$(id -u)/niri.*.sock
        exec ${lib.getExe pkgs.niri} -c ${niriConfig}
      '';
      KillSignal = "SIGKILL";
      TimeoutStopSec = "5s";
      Restart = "always";
      RestartSec = "2s";
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
