{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:

{
  imports = [
    inputs.nixos-avf.nixosModules.avf
  ];

  networking.hostName = "cheetah-avf";

  avf.defaultUser = "reo101";

  rix101.wayland = {
    enable = true;
    user = "reo101";
    portal = {
      desktopNames = [ "niri" ];
      fileChooserBackend = "gtk";
    };
    niri.homeManagerModule = ./homeModules/niri.nix;
    stylix.colorscheme = inputs.nix-colors.colorSchemes.tokyo-night-dark;
  };

  nix = {
    settings = {
      trusted-users = [
        "root"
        "reo101"
      ];
    };
  };

  programs.zsh.enable = true;

  users.users.reo101 = {
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHBc0G9jbQYzwWqIzj504MrxsamFBzbISltpTrLaFUg1 cardno:31_228_281"
    ];
  };

  services.openssh = {
    enable = true;
    ports = [ 8222 ];
    openFirewall = true;
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  environment.systemPackages = [
    pkgs.waypipe
  ];
  environment.variables = {
    WAYLAND_DISPLAY = lib.mkForce "wayland-1";
    DISPLAY = lib.mkForce ":1";
  };

  # Direct Niri-on-DRM starts but never exposes an output on AVF's virtio-gpu
  # (Niri reports "no allocator available" and `niri msg outputs` is `{}`).
  # Keep Weston as the AVF DRM presenter and run the Home-Manager-managed Niri
  # config nested inside it; apps still connect to Niri on wayland-1/:1.
  services.greetd.enable = lib.mkForce false;
  systemd.user.services.weston.restartIfChanged = false;
  systemd.user.services.niri-avf = {
    description = "Nested Niri Wayland compositor for AVF graphics";
    wantedBy = [ "default.target" ];
    requires = [ "weston.service" ];
    after = [ "weston.service" ];
    restartIfChanged = false;
    path = [
      config.home-manager.users.reo101.programs.niri.package
      pkgs.xwayland-satellite
      pkgs.bash
      pkgs.procps
      pkgs.systemd
    ];

    environment = {
      LIBGL_DRIVERS_PATH = "${pkgs.mesa.drivers}/lib/dri";
      LD_LIBRARY_PATH = "/run/opengl-driver/lib";
      WAYLAND_DISPLAY = "wayland-0";
      DISPLAY = "";
      XDG_CURRENT_DESKTOP = "niri";
      XDG_SESSION_TYPE = "wayland";
    };

    serviceConfig = {
      ExecStartPre = "${pkgs.coreutils}/bin/rm -f %t/wayland-1 %t/wayland-1.lock";
      ExecStart = "${lib.getExe config.home-manager.users.reo101.programs.niri.package} -c ${pkgs.writeText "niri-avf-config.kdl" config.home-manager.users.reo101.programs.niri.finalConfig}";
      Restart = "on-failure";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  # The nixos-avf/seatd unit uses Type=notify through s6-notify-socket-from-fd,
  # but in this AVF VM seatd starts successfully without ever completing the
  # systemd start job. That makes activation wait until timeout. Run it as a
  # plain foreground service instead.
  systemd.services.seatd.serviceConfig = {
    ExecStart = lib.mkForce "${pkgs.seatd}/bin/seatd -u root -g seat -l info";
    Type = lib.mkForce "simple";
    NotifyAccess = lib.mkForce "none";
  };

  systemd.services.avahi_ttyd = {
    wants = [ "avahi-daemon.service" ];
    after = [ "avahi-daemon.service" ];
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig.RestartSec = "5s";
  };

  time.timeZone = "Europe/Sofia";
  i18n.defaultLocale = "en_US.UTF-8";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "26.05";
}
