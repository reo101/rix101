{ lib, pkgs, config, ... }:

let
  sunshineUser = "jeeves";
  sunshineGroup = "users";
  niriTTY = "tty3";
  niriVT = "3";

  # Keep X11 root/pointer bounds in sync when the streaming output changes mode.
  xwaylandSatellite = lib.infuse pkgs.xwayland-satellite {
    __output.patches.__append = [ ./xwayland-satellite-output-size.patch ];
    __output.doCheck.__assign = true;
    __output.nativeCheckInputs.__append = [ pkgs.xwayland ];
    __output.preCheck.__append = ''
      export XDG_RUNTIME_DIR=$(mktemp -d)
    '';
    __output.checkFlags.__assign = [ "output_resize_logical_size_before_mode" ];
  };

  # NOTE: GPU and display configuration
  #
  # Stable PCI paths for the iGPU (AMD Raphael integrated) and dGPU (AMD RX
  # 7900 XTX). cardN/renderDN numbering is assigned at boot and not stable.
  #
  # We use EDID firmware injection on an unused port of the dGPU to create
  # a virtual display that the real GPU can render to with full acceleration.
  gpuCards = {
    igpu = {
      card = "/dev/dri/by-path/pci-0000:1a:00.0-card";
      render = "/dev/dri/by-path/pci-0000:1a:00.0-render";
    };
    dgpu = {
      card = "/dev/dri/by-path/pci-0000:03:00.0-card";
      render = "/dev/dri/by-path/pci-0000:03:00.0-render";
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
  sunshineNiriDir = "/run/sunshine-niri";
  niriSocket = "${sunshineNiriDir}/niri.sock";
  sunshineVersion = "2026.906.222525";
  sunshineSource = pkgs.fetchFromGitHub {
    owner = "LizardByte";
    repo = "Sunshine";
    rev = "v${sunshineVersion}";
    hash = "sha256-2Ab8KSX/SY3OFeqhwgYmMX/HQdV/jcCpNAFOEdG3V8w=";
    fetchSubmodules = true;
  };
  sunshineUi = pkgs.buildNpmPackage {
    pname = "sunshine-ui";
    version = sunshineVersion;
    src = sunshineSource;
    npmDepsHash = "sha256-w9/11m9PnwxuA9qJJH3JiGwperBSKNUGW2QAHFiejxo=";
    installPhase = ''
      mkdir -p "$out"
      cp -a . "$out"/
    '';
  };
  sunshineFfmpeg = pkgs.fetchzip {
    url = "https://github.com/LizardByte/build-deps/releases/download/v2026.724.203728/Linux-x86_64-ffmpeg.tar.gz";
    hash = "sha256-ERw553AsQ0s/7oEXCiwjJjZEp1hpe9aCgiEBRs0K0R0=";
  };
  sunshinePackage = lib.infuse pkgs.sunshine {
    __output.version.__assign = sunshineVersion;
    __output.src.__assign = sunshineSource;
    __output.ui.__assign = sunshineUi;
    __output.cmakeFlags = [
      {
        __filter = lib.compose [
          (lib.hasPrefix "-DFFMPEG_PREPARED_BINARIES:")
          lib.not
        ];
      }
      {
        __append = [
          (lib.cmakeBool "SUNSHINE_ENABLE_TRAY" false)
          (lib.cmakeFeature "FFMPEG_PREPARED_BINARIES" "${sunshineFfmpeg}")
        ];
      }
    ];
  };

  # Sunshine only serves PNG app images. Generate distinct, immutable icons so
  # Moonlight does not turn the session controls into five identical tiles.
  sunshineSteamIcon = "${sunshinePackage}/assets/steam.png";
  sunshineDesktopIcon = "${sunshinePackage}/assets/desktop.png";
  sunshineIcons = pkgs.runCommand "sunshine-app-icons" {
    nativeBuildInputs = [ pkgs.imagemagick pkgs.dejavu_fonts ];
  } ''
    set -euo pipefail
    mkdir -p "$out"

    make_icon() {
      input="$1"
      output="$2"
      label="$3"
      color="$4"
      # Scale the former 512px-square layout to the source cover's height.
      local layout_height=512 layout_banner_height=114 layout_pointsize=34 layout_text_offset=30
      local width height banner_height offset pointsize text_offset
      read -r width height < <(${lib.getExe pkgs.imagemagick} identify -format '%w %h\n' "$input")
      banner_height=$((height * layout_banner_height / layout_height))
      offset=$((banner_height / 2))
      pointsize=$((height * layout_pointsize / layout_height))
      text_offset=$((height * layout_text_offset / layout_height))

      ${lib.getExe pkgs.imagemagick} "$input" \
        -crop "''${width}x$((height - offset))+0+''${offset}" +repage \
        -gravity north -extent "''${width}x''${height}" \
        -gravity northwest -fill "$color" \
        -draw "rectangle 0,$((height - banner_height)) ''${width},''${height}" \
        -gravity south -fill white \
        -font ${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSans-Bold.ttf \
        -pointsize "$pointsize" -annotate "+0+$text_offset" "$label" "$out/$output"
    }

    make_icon ${sunshineSteamIcon} steam-close.png "CLOSE ON EXIT" '#a51d2d'
    make_icon ${sunshineSteamIcon} steam-persistent.png "KEEP RUNNING" '#26a269'
    make_icon ${sunshineSteamIcon} steam-stop.png "STOP STEAM" '#c01c28'
    make_icon ${sunshineDesktopIcon} desktop.png "DESKTOP" '#5e5c64'
  '';
  sunshineSink = "sink-sunshine-stereo";
  sunshineSurround51Sink = "sink-sunshine-surround51";
  sunshineSurround71Sink = "sink-sunshine-surround71";

  steamBigPicture = pkgs.writeShellScript "steam-big-picture" ''
    export PULSE_SERVER="unix:$XDG_RUNTIME_DIR/pulse/native"
    export PULSE_SINK=${lib.escapeShellArg sunshineSink}
    export SDL_AUDIODRIVER=pulse
    export WINEDLLOVERRIDES='winepulse.drv=b;winealsa.drv=d'

    exec ${lib.getExe' pkgs.util-linux "setpriv"} --ambient-caps -all --inh-caps -all \
      ${lib.getExe' pkgs.coreutils "env"} \
        PULSE_SERVER="unix:$XDG_RUNTIME_DIR/pulse/native" \
        PULSE_SINK=${lib.escapeShellArg sunshineSink} \
        SDL_AUDIODRIVER=pulse \
        WINEDLLOVERRIDES='winepulse.drv=b;winealsa.drv=d' \
        ${lib.getExe config.programs.steam.package} -tenfoot
  '';

  # Niri config for persistent session with named workspaces
  niriConfig = pkgs.writeText "niri-sunshine.kdl" /* kdl */ ''
    debug {
      // Force rendering on the dGPU
      render-drm-device "${gpuCards.dgpu.render}"
      // Ignore the iGPU
      ignore-drm-device "${gpuCards.igpu.render}"
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
    output "${virtualDisplayPort}" {
      mode "${builtins.toString virtualDisplay.width}x${builtins.toString virtualDisplay.height}"
      scale 1
      focus-at-startup
    }

    // Let Niri manage Xwayland geometry for Steam and games.
    xwayland-satellite {
      path "${lib.getExe xwaylandSatellite}"
    }

    hotkey-overlay {
      skip-at-startup
    }

    // Named workspaces (steam first = top row)
    workspace "steam" {
      open-on-output "${virtualDisplayPort}"
    }
    workspace "desktop" {
      open-on-output "${virtualDisplayPort}"
    }

    // Steam Big Picture always goes to the Steam workspace.
    window-rule {
      match app-id="steam"
      open-on-workspace "steam"
      open-fullscreen true
    }

    // Keybinds (Alt as modifier)
    binds {
      Alt+Return { spawn "${lib.getExe pkgs.ghostty}"; }
      Alt+Up { toggle-overview; }
    }
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
    set -u
    for _ in $(seq 1 40); do
      if ${niriMsg} action focus-workspace "$1"; then
        exit 0
      fi
      sleep 0.25
    done
    exit 1
  ''; 

  sunshineMode = pkgs.writeShellScript "sunshine-mode" ''
    set -eu
    width="''${SUNSHINE_CLIENT_WIDTH:-1920}"
    height="''${SUNSHINE_CLIENT_HEIGHT:-1080}"
    refresh="''${SUNSHINE_CLIENT_FPS:-144}"

    case "$width:$height:$refresh" in
      *[!0-9:]* | :* | *: | *::* | *:*:*:*) width=1920; height=1080; refresh=144 ;;
      *) ;;
    esac
    case "$width:$height:$refresh" in
      0:* | *:0:* | *:*:0) width=1920; height=1080; refresh=144 ;;
    esac

    mode_file="/run/user/$(id -u)/sunshine-client-mode"
    umask 077
    printf 'width=%s\nheight=%s\nrefresh=%s\n' "$width" "$height" "$refresh" > "$mode_file"
    ${niriMsg} output ${virtualDisplayPort} on
    ${niriMsg} output ${virtualDisplayPort} custom-mode "''${width}x''${height}@''${refresh}"
    ${niriMsg} output ${virtualDisplayPort} scale 1
  '';

  steamStop = pkgs.writeShellScript "steam-stop" ''
    set -eu
    systemctl=${lib.getExe' pkgs.systemd "systemctl"}
    ${niriFocus} desktop || true
    "$systemctl" --user stop sunshine-steam-direct.service
    "$systemctl" --user restart wireplumber.service sunshine-audio-sinks.service
  '';

  steamStart = pkgs.writeShellScript "steam-start" ''
    set -eu
    systemctl=${lib.getExe' pkgs.systemd "systemctl"}
    pactl=${lib.getExe' pkgs.pulseaudio "pactl"}
    # Hide physical sinks while gaming so Wine/Proton only enumerates Sunshine.
    "$pactl" list short cards | ${lib.getExe' pkgs.gawk "awk"} '{print $2}' | while read -r card; do
      "$pactl" set-card-profile "$card" off
    done
    "$systemctl" --user start sunshine-audio-sinks.service
    ${niriFocus} steam
    . ${sunshineMode}
    "$systemctl" --user start sunshine-steam-direct.service
  '';

  steamStopKeepRunning = pkgs.writeShellScript "steam-stop-keep-running" ''
    ${niriFocus} desktop || true
  '';

  desktopStart = pkgs.writeShellScript "desktop-start" ''
    ${niriFocus} desktop
    . ${sunshineMode}
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
    package = sunshinePackage;
    autoStart = true;
    openFirewall = true;
    capSysAdmin = true;  # Required for KMS capture
    settings = {
      # WARN: Default is `47989`, which `+21` (done by the `sunshine` module) overlaps with `OpenCloud`'s `48010`
      port = 47989;
      # KMS capture from the virtual display on the real GPU
      capture = "kms";
      # Select the dGPU for hardware encoding.
      adapter_name = gpuCards.dgpu.render;
      # Stable DRM connector name. Numeric monitor indexes depend on discovery order.
      output_name = virtualDisplayPort;
      # Capture the monitor for the virtual sink Steam is routed to
      audio_sink = sunshineSink;
      # The reverse-proxied Web UI is a trusted state-changing API origin.
      csrf_allowed_origins = "https://sunshine.jeeves.reo101.xyz";
    };
    applications = {
      apps = [
        {
          # Destructive variant: ending the Sunshine session also ends Steam.
          name = "Steam Big Picture (close on exit)";
          image-path = "${sunshineIcons}/steam-close.png";
          prep-cmd = [
            {
              do = "${steamStart}";
              undo = "${steamStop}";
            }
          ];
        }
        {
          # Persistent variant: end streaming without ending Steam.
          # Starting this app again reapplies the new client output mode first.
          name = "Steam Big Picture (keep running)";
          image-path = "${sunshineIcons}/steam-persistent.png";
          prep-cmd = [
            {
              do = "${steamStart}";
              undo = "${steamStopKeepRunning}";
            }
          ];
        }
        {
          # Explicitly stop the persistent Steam session.
          name = "Stop Steam";
          image-path = "${sunshineIcons}/steam-stop.png";
          cmd = "${lib.getExe' pkgs.coreutils "true"}";
          prep-cmd = [
            {
              do = "${steamStop}";
              undo = "";
            }
          ];
        }
        {
          name = "Desktop";
          image-path = "${sunshineIcons}/desktop.png";
          prep-cmd = [
            {
              do = "${desktopStart}";
              undo = "";
            }
          ];
        }
      ];
    };
  };

  # NOTE: Virtual Input Devices configuration

  # Sunshine configures the uinput permissions, but does not load its module.
  boot.kernelModules = [ "uhid" "uinput" ];
  # udev's static_node rule did not materialize this node after a late module
  # load, so ensure it exists before Sunshine starts after every boot.
  systemd.tmpfiles.settings."sunshine-uinput" = {
    "/dev/uinput".c = {
      mode = "0660";
      user = "root";
      group = "uinput";
      argument = "10:223";
    };
  };
  services.udev.extraRules = ''
    KERNEL=="uhid", MODE="0660", GROUP="input"
  ''; 

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

  systemd.user.services.sunshine-audio-sinks = {
    description = "Sunshine virtual audio sinks";
    after = [ "pipewire-pulse.service" ];
    wants = [ "pipewire-pulse.service" ];
    wantedBy = [ "pipewire-pulse.service" ];
    partOf = [ "pipewire-pulse.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "sunshine-audio-sinks" ''
        set -euo pipefail
        pactl=${lib.getExe' pkgs.pulseaudio "pactl"}
        grep=${lib.getExe' pkgs.gnugrep "grep"}
        has_sink() { "$pactl" list short sinks | "$grep" -q '^.*[[:space:]]'"$1"'[[:space:]]'; }
        has_loopback() { "$pactl" list modules | "$grep" -q "source=$1.monitor sink=${sunshineSink}"; }

        has_sink ${sunshineSink} || \
          "$pactl" load-module module-null-sink sink_name=${sunshineSink} channels=2 rate=48000 sink_properties=device.description=Sunshine-Stereo
        has_sink ${sunshineSurround51Sink} || \
          "$pactl" load-module module-null-sink sink_name=${sunshineSurround51Sink} channels=6 rate=48000 channel_map=front-left,front-right,front-center,lfe,rear-left,rear-right sink_properties=device.description=Sunshine-Surround-5.1
        has_sink ${sunshineSurround71Sink} || \
          "$pactl" load-module module-null-sink sink_name=${sunshineSurround71Sink} channels=8 rate=48000 channel_map=front-left,front-right,front-center,lfe,rear-left,rear-right,side-left,side-right sink_properties=device.description=Sunshine-Surround-7.1

        has_loopback ${sunshineSurround51Sink} || \
          "$pactl" load-module module-loopback source=${sunshineSurround51Sink}.monitor sink=${sunshineSink} latency_msec=20
        has_loopback ${sunshineSurround71Sink} || \
          "$pactl" load-module module-loopback source=${sunshineSurround71Sink}.monitor sink=${sunshineSink} latency_msec=20
        "$pactl" set-default-sink ${sunshineSink} || true
        "$pactl" set-default-source ${sunshineSink}.monitor || true
      '';
    };
  };

  # Steam's launcher is a user service, not an anonymous Sunshine descendant.
  # That gives stop/restart semantics to systemd rather than pgrep/pkill regexes.
  systemd.user.services.sunshine-steam-direct = {
    after = [ "graphical-session.target" "sunshine-audio-sinks.service" ];
    wants = [ "sunshine-audio-sinks.service" ];
    requisite = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = steamBigPicture;
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };

  systemd.user.services.sunshine = {
    wants = [ "sunshine-audio-sinks.service" ];
    serviceConfig = {
      PrivateDevices = false;
      KillSignal = "SIGKILL";
      TimeoutStopSec = "5s";
    };
  };

  # NOTE: Niri session for Sunshine streaming
  # Kept running so Sunshine has a KMS display to capture before app prep runs

  systemd.services.sunshine-niri = {
    description = "Niri compositor for Sunshine streaming";
    conflicts = [ "getty@${niriTTY}.service" "autovt@${niriTTY}.service" ];
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-user-sessions.service" "seatd.service" ];
    wants = [ "seatd.service" ];

    environment = {
      XDG_RUNTIME_DIR = "/run/user/%U";
      WLR_DRM_DEVICES = gpuCards.dgpu.card;
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
      RuntimeDirectory = "sunshine-niri";
      RuntimeDirectoryMode = "0755";
      # Niri needs to own the active VT before seatd can grant it DRM master.
      ExecStartPre = "+${lib.getExe' pkgs.kbd "chvt"} ${niriVT}";
      ExecStart = pkgs.writeShellScript "niri-run" ''
        rm -f /run/user/$(id -u)/niri.*.sock ${niriSocket}
        ${lib.getExe pkgs.niri} --session -c ${niriConfig} &
        pid=$!
        trap 'kill "$pid" 2>/dev/null || true' TERM INT EXIT
        for _ in $(seq 1 50); do
          sock=$(ls /run/user/$(id -u)/niri.*.sock 2>/dev/null | head -n1 || true)
          if [ -n "$sock" ]; then
            ln -sfn "$sock" ${niriSocket}
            break
          fi
          sleep 0.1
        done
        wait "$pid"
      '';
      KillSignal = "SIGTERM";
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
