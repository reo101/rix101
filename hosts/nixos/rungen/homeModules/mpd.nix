{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:

{
  # NOTE: two MPD instances coexist:
  # - the satellite on 6601 (proxied to jeeves, see `rix101.mpd-satellite`)
  # - this local one on 6600, with its own `~/Music` library for offline use
  services.mpd = {
    enable = true;
    package = pkgs.mpd;
    network.startWhenNeeded = true;
    # `rix101.mpd-satellite` owns `MPD_HOST`/`MPD_PORT` so MPD clients
    # default to the satellite; reach this local instance explicitly
    # with `MPD_PORT=6600 rmpc` (e.g. on a plane).
    enableSessionVariables = false;

    extraConfig = ''
      audio_output {
        type "pipewire"
        name "MPD PipeWire"
      }
    '';
  };

  services.mpd-discord-rpc = {
    enable = true;
    settings = {
      hosts = [ "localhost:6601" ];
      format = {
        details = "$title";
        state = "On $album by $artist";
      };
    };
  };

  services.mpd-mpris = {
    enable = true;
    mpd = {
      useLocal = false;
      host = "127.0.0.1";
      port = 6601;
    };
  };
}
