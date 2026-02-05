{
  config,
  pkgs,
  lib,
  ...
}:
{
  environment.systemPackages = [
    pkgs.mangohud
    pkgs.protonup-ng
    pkgs.r2modman
    pkgs.protontricks
  ];

  environment.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "/home/reo101/.steam/root/compatibilitytools.d";
  };

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

  programs.steam = {
    enable = true;
    extest.enable = true;
    protontricks.enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.gamemode.enable = true;
}
