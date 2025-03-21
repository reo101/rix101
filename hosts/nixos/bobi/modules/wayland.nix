{ inputs, config, lib, pkgs, ... }:

{
  environment.sessionVariables = {
    # If cursor becomes invisible
    # WLR_NO_HARDWARE_CURSORS = "1";
    # Hint electron apps to use wayland
    NIXOS_OZONE_WL = "0";
    # Firefox Wayland
    MOZ_ENABLE_WAYLAND = "1";
    QT_WAYLAND_DISABLE_DECORATION = "1";
  };

  services.greetd = {
    enable = true;
    package = pkgs.greetd.tuigreet;
    settings = {
      default_session = {
        command = "${lib.getExe pkgs.greetd.tuigreet} --cmd ${lib.getExe' pkgs.niri "niri-session"}";
      };
    };
  };

  programs.river = {
    enable = true;
    package = pkgs.river;
  };

  environment.systemPackages = with pkgs; [
    niri
    legcord
  ];

  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  services.libinput = {
    enable = true;
    mouse.accelProfile = "flat";
    touchpad.accelProfile = "flat";
  };
}
