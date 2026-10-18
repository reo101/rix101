{ lib, ... }:

let
  definitions = {
    nixos = [
      "default-editor"
      "nix-general"
      "desktop"
      "jellyfin"
      "battery-notify"
      "slskd"
      "taskchampion-sync-server"
      "vaultwarden"
    ];
    darwin = [
      "nix-general"
      "system"
      "brew"
      "yabai"
    ];
    nixOnDroid = [ "nix-general" ];
    homeManager = [
      "rix101-shell"
      "rix101-scm"
      "rix101-river"
      "rix101-firefox"
      "rix101-wezterm"
      "rix101-mpd-satellite"
      "rix101-spotify"
    ];
  };
in
{
  options.auto.modules.result = lib.mkOption {
    type = lib.types.lazyAttrsOf (lib.types.lazyAttrsOf lib.types.deferredModule);
  };
  config.auto.modules.result = lib.mapAttrs (
    class: names:
    lib.genAttrs names (name: {
      key = "aspect-catalog-fixture/${class}/${name}";
      config.test.values = [ name ];
    })
  ) definitions;
}
