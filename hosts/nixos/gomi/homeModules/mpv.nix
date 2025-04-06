{ config, lib, pkgs, ... }:

{
  programs.mpv = {
    enable = true;
    package = pkgs.mpv;
    # package = pkgs.mpv-unwrapped.wrapper {
    #   mpv = pkgs.mpv-unwrapped.override {
    #     vapoursynthSupport = true;
    #     # ffmpeg_5 = pkgs.ffmpeg_5-full;
    #   };
    #   youtubeSupport = true;
    # };
    scripts = with pkgs.mpvScripts; [
      crop
      cutter
      mpris
      thumbfast
      sponsorblock
      mpv-cheatsheet
      mpv-discord
      # NOTE: Anki cards
      mpvacious
    ];
    config = {
      # profile = "gpu-hq";
      # force-window = true;
      ytdl-format = "bestvideo+bestaudio";
      # cache-default = 4000000;
      glsl-shader = "${pkgs.mpv-shim-default-shaders}/share/mpv-shim-default-shaders/shaders/FSRCNNX_x2_8-0-4-1.glsl";
    };
    bindings = {
      "WHEEL_UP" = "seek 10";
      "WHEEL_DOWN" = "seek -10";
      "Alt+0" = "set window-scale 0.5";
      "h" = "seek -5";
      "j" = "seek -60";
      "k" = "seek 60";
      "l" = "seek 5";
      "S" = "cycle sub";
    };
  };
}
