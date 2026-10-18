{ config, ... }:

let
  modules = config.auto.modules.result;
in
{
  composition.aspects = { aspects, ... }: {
    systemDefaults = {
      nixos.imports = [
        modules.nixos.default-editor
        modules.nixos.nix-general
      ];
      darwin.imports = [ modules.darwin.nix-general ];
      nixOnDroid.imports = [ modules.nixOnDroid.nix-general ];
    };

    shell.homeManager.imports = [ modules.homeManager.rix101-shell ];
    sourceControl.homeManager.imports = [ modules.homeManager.rix101-scm ];
    standardEnvironment.includes = [
      aspects.systemDefaults
      aspects.shell
      aspects.sourceControl
    ];

    wayland.nixos.imports = [ modules.nixos.desktop ];
    river = {
      includes = [ aspects.wayland ];
      homeManager.imports = [ modules.homeManager.rix101-river ];
    };
    firefox.homeManager.imports = [ modules.homeManager.rix101-firefox ];
    wezterm.homeManager.imports = [ modules.homeManager.rix101-wezterm ];
    mpdSatellite.homeManager.imports = [ modules.homeManager.rix101-mpd-satellite ];
    spotify.homeManager.imports = [ modules.homeManager.rix101-spotify ];
    jellyfin.nixos.imports = [ modules.nixos.jellyfin ];
    batteryNotification.nixos.imports = [ modules.nixos.battery-notify ];

    slskd.nixos.imports = [ modules.nixos.slskd ];
    taskSynchronization.nixos.imports = [ modules.nixos.taskchampion-sync-server ];
    vaultwarden.nixos.imports = [ modules.nixos.vaultwarden ];
    hostedServices.includes = [
      aspects.slskd
      aspects.taskSynchronization
      aspects.vaultwarden
    ];

    darwinSystem.darwin.imports = [ modules.darwin.system ];
    homebrew.darwin.imports = [ modules.darwin.brew ];
    yabai.darwin.imports = [ modules.darwin.yabai ];

    workstation.includes = [
      aspects.standardEnvironment
      aspects.wayland
      aspects.firefox
    ];
    riverWorkstation.includes = [
      aspects.standardEnvironment
      aspects.river
      aspects.wezterm
    ];
    darwinWorkstation.includes = [
      aspects.standardEnvironment
      aspects.darwinSystem
      aspects.homebrew
      aspects.yabai
      aspects.wezterm
    ];
    server.includes = [
      aspects.standardEnvironment
      aspects.hostedServices
    ];
  };
}
