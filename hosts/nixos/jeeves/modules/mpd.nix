{ inputs, lib, pkgs, config, ... }:

let
  # mpdPort = 6600;
  mpdPort = config.services.mpd.settings.port;
in
{
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    jack.enable = true;
  };

  services.mpd = {
    enable = true;
    startWhenNeeded = true;
    openFirewall = false;

    settings = {
      # TODO: translate from old `extraConfig`
      # "audio_output" = {
      #   type = "pipewire";
      #   name = "MPD PipeWire";
      # };
      music_directory = "/data/media/music";
      bind_to_address = "any";
      # The central MPD is the database authority for satellite instances;
      # pick up Lidarr imports without manual `update`.
      # NOTE: MPD 0.24 dropped the `inotify` key; `auto_update` enables it.
      auto_update = true;
    };
  };
  services.mpd.user = "jeeves";
  systemd.services.mpd.environment = {
    # MPD is a system service running as jeeves; point it at jeeves' normal
    # user PipeWire socket instead of a system-wide PipeWire daemon.
    XDG_RUNTIME_DIR = "/run/user/${toString config.users.users.jeeves.uid}";
  };

  # services.mopidy = let
  #   mopidyPackagesOverride = pkgs.mopidyPackages.overrideScope (prev: final: {
  #     extraPkgs = pkgs: [
  #       pkgs.yt-dlp
  #     ];
  #   });
  # in {
  #   enable = true;
  #   extensionPackages = with mopidyPackagesOverride; [
  #     mopidy-youtube
  #     mopidy-ytmusic
  #     mopidy-spotify
  #     mopidy-jellyfin
  #     mopidy-mpd
  #     mopidy-mpris
  #     mopidy-scrobbler
  #   ];
  #   configuration = /* ini */ ''
  #     [youtube]
  #     youtube_dl_package = yt_dlp
  #
  #     [mpd]
  #     enabled = true
  #     hostname = ::
  #     port = ${builtins.toString mpdPort}
  #   '';
  # };

  # services.icecast = {
  #   enable = true;
  # };

  # services.nginx.virtualHosts."mpd.jeeves.lan" = {
  #   locations."/" = {
  #     # proxyPass = "http://127.0.0.1:${builtins.toString mpdPort}";
  #     proxyPass = "http://127.0.0.1:${builtins.toString config.services.mpd.network.port}";
  #     proxyWebsockets = true;
  #   };
  # };
  # services.nginx.streamConfig = ''
  #   # TCP-level passthrough for MPD
  #   server {
  #     listen ${builtins.toString mpdPort};
  #     proxy_pass 127.0.0.1:${builtins.toString config.services.mpd.network.port};
  #     proxy_timeout 600s;
  #     proxy_connect_timeout 5s;
  #   }
  # '';

  networking.firewall.interfaces = lib.genAttrs [
    "eth0"
    "wlan0"
    "wg0"
  ] (_: {
    allowedTCPPorts = [ mpdPort ];
  });
}
