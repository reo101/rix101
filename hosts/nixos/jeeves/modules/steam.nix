{
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.self.nixosModules.steam
  ];

  environment.systemPackages = [
    pkgs.mangohud
    pkgs.protonup-ng
    pkgs.r2modman
    pkgs.protontricks
    pkgs.custom.viiper
    config.boot.kernelPackages.usbip
  ];

  # VIIPER/USBIP input bridge
  # NOTE: This lets a remote feeder (like a phone-side controller bridge)
  # create a virtual USB controller on `jeeves`, while `VIIPER`
  # auto-attaches it locally through the Linux `USB`/`IP` `VHCI` host.
  boot.kernelModules = [ "vhci-hcd" ];
  system.services.viiper.imports = [ pkgs.custom.viiper.services.default ];

  # The remote feeder talks to `VIIPER`'s API port
  # The raw `USB`/`IP` port remains firewalled
  # Local auto-attach uses localhost
  networking.firewall.allowedTCPPorts = [ config.system.services.viiper.viiper.apiPort ];

  # Steam
  rix101.steam.extest = {
    enable = true;
    users = [ "jeeves" ];
  };

  hardware.steam-hardware.enable = true;

  # - `hardware.steam-hardware` uses uaccess `ACL`s for Valve `HID` devices,
  #   which works for a normal local `logind` seat
  # - `jeeves` runs Steam in a headless `Sunshine`/`niri` user service, so no
  #   active-seat `ACL` is applied and the puck stays `root:root` `0660`
  # - Give the `input` group direct access so Steam
  #   can take the controller out of lizard mode
  services.udev.extraRules = ''
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="28de", MODE="0660", GROUP="input", TAG+="uaccess"
    KERNEL=="hidraw*", ATTRS{idVendor}=="28de", MODE="0660", GROUP="input", TAG+="uaccess"
  '';

  programs.steam = {
    enable = true;
    protontricks.enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  # Proton
  environment.sessionVariables = {
    # NOTE: run `protonup -d "~/.steam/root/compatibilitytools.d"`
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "${config.home-manager.users.jeeves.home.homeDirectory}/.steam/root/compatibilitytools.d";
  };

  # Core graphics
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };

    amdgpu = {
      opencl = {
        enable = true;
      };
    };
  };

  # Compositing and optimisation
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };
  programs.gamemode = {
    enable = true;
  };

  # Better scheduling for gaming
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
  };

  # VR
  programs.alvr = {
    enable = true;
    openFirewall = true;
  };

  # Sound
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse = {
      enable = true;
    };
    jack = {
      enable = true;
    };
  };

  services.dbus = {
    enable = true;
    packages = [ pkgs.dconf ];
  };
}
