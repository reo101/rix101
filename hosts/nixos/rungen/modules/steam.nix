{
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
    pkgs.moonlight-qt
    pkgs.custom.viiper
    pkgs.custom.sisr
  ];

  boot.kernelModules = [ "vhci-hcd" ];

  system.services.viiper.imports = [ pkgs.custom.viiper.services.default ];

  environment.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "/home/reo101/.steam/root/compatibilitytools.d";
  };

  services.lact.enable = true;

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };

    amdgpu = {
      initrd.enable = true;
      opencl.enable = true;
    };
  };

  rix101.steam.extest = {
    enable = true;
    users = [ "reo101" ];
  };

  hardware.steam-hardware.enable = true;
  programs.steam = {
    enable = true;
    protontricks.enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  programs.gamescope = {
    enable = true;
    # FIXME: <https://github.com/nixos/nixpkgs/issues/523200>
    capSysNice = false;
  };

  programs.gamemode.enable = true;
}
