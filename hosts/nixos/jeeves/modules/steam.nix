{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    mangohud
    protonup-ng
    r2modman
    protontricks
  ];

  # Steam
  programs.steam = {
    enable = true;
    extest.enable = true;
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
