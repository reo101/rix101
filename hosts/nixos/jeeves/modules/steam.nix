{ inputs, pkgs, config, ... }:
{
  imports = [
    inputs.self.nixosModules.steam
    inputs.steamlesslink.nixosModules.steamless-uhid
  ];

  environment.systemPackages = [
    pkgs.mangohud
    pkgs.protonup-ng
    pkgs.r2modman
    pkgs.protontricks
  ];

  services.steamless-uhid = {
    enable = true;
    user = "jeeves";
    listenHost = "0.0.0.0";
    listenPort = 3244;
    iroh.enable = true;
  };

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
