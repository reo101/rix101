{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:

{
  services.mpd = {
    enable = true;
    package = pkgs.mpd;
    network.startWhenNeeded = true;

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
      hosts = [ "localhost:6600" ];
      format = {
        details = "$title";
        state = "On $album by $artist";
      };
    };
  };

  services.mpd-mpris = {
    enable = true;
  };
}
