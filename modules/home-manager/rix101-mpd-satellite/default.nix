{
  lib,
  pkgs,
  config,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    ;

  cfg = config.rix101.mpd-satellite;

  stateDir = "${config.home.homeDirectory}/.local/state/mpd-satellite";

  satelliteConfig = pkgs.writeText "mpd-satellite.conf" ''
    # Music library lives on the central server; files are streamed over SMB
    music_directory "smb://${cfg.host}/${cfg.share}"

    bind_to_address "127.0.0.1"
    port "${toString cfg.localPort}"

    state_file "${stateDir}/state"
    playlist_directory "${stateDir}/playlists"

    # All database queries are proxied to the central MPD instance,
    # so there is no local tag cache; stickers (ratings, likes) are
    # forwarded to the central instance too.
    database {
      plugin "proxy"
      host "${cfg.host}"
      port "${toString cfg.port}"
    }

    audio_output {
      type "pipewire"
      name "MPD PipeWire"
    }
  '';
in
{
  options = {
    rix101.mpd-satellite = {
      enable = mkEnableOption "rix101 MPD satellite client";

      host = mkOption {
        type = lib.types.str;
        default = "jeeves.lan";
        description = ''
          Hostname of the central MPD server. Used both for the proxied
          database (MPD protocol on `port`) and for the SMB music share.
        '';
      };

      port = mkOption {
        type = lib.types.port;
        default = 6600;
        description = ''
          Port of the central MPD instance, used for the proxied database.
        '';
      };

      localPort = mkOption {
        type = lib.types.port;
        default = 6601;
        description = ''
          Port this satellite listens on locally (must differ from the
          local MPD instance, which owns 6600).
        '';
      };

      share = mkOption {
        type = lib.types.str;
        default = "music";
        description = "SMB share exposing the central music library";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.mpd-satellite = {
      Unit = {
        Description = "MPD satellite (database proxied to ${cfg.host})";
        After = [ "network-online.target" "mpd-satellite.socket" ];
        Requires = [ "mpd-satellite.socket" ];
      };
      Service = {
        ExecStart = "${lib.getExe pkgs.mpd} --no-daemon ${satelliteConfig}";
        Type = "notify";
      };
    };

    # MPD requires the playlist directory to exist at startup
    # HACK: home-manager does not expose the `.settings` interface yet
    # systemd.user.tmpfiles.settings."mpd-satellite" = {
    #   ${stateDir}.d = { mode = "0755"; };
    #   "${stateDir}/playlists".d = { mode = "0755"; };
    # };
    systemd.user.tmpfiles.rules = [
      # Type Path User Group
      "d ${stateDir} 0755 - -"
      "d ${stateDir}/playlists 0755 - -"
    ];

    systemd.user.sockets.mpd-satellite = {
      Unit.Description = "MPD satellite socket";
      Socket = {
        ListenStream = toString cfg.localPort;
        Backlog = 5;
        KeepAlive = true;
      };
      Install.WantedBy = [ "sockets.target" ];
    };

    # rmpc (and other MPD clients) default to the satellite;
    # override with `MPD_PORT=6600 rmpc` for the local library instance.
    home.sessionVariables = {
      MPD_HOST = "127.0.0.1";
      MPD_PORT = toString cfg.localPort;
    };

    home.packages = [
      pkgs.rmpc
    ];
  };

  meta = {
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
