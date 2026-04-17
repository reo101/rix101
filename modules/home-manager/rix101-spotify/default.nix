{ inputs, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.rix101.spotify;

  inherit (lib)
    mkEnableOption
    mkOption
    types
    mkIf
    optionals
    optionalString
    mkMerge
    ;
in
{
  imports = [
    inputs.spicetify-nix.homeManagerModules.default
  ];

  options = {
    rix101.spotify = {
      enable = mkEnableOption "rix101 spotify setup";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      spotify
    ];

    programs.spicetify =
      let
        spicePkgs = inputs.spicetify-nix.packages.${pkgs.system}.default;
      in
      {
        enable = true;
        spotifyPackage = pkgs.spotify;

        theme = spicePkgs.themes.text;
        colorScheme = "text";

        enabledExtensions = with spicePkgs.extensions; [
          adblock
          autoVolume
          copyToClipboard
          fullAlbumDate
          fullAppDisplay
          genre
          goToSong
          groupSession
          hidePodcasts
          history
          keyboardShortcut
          newReleases
          lastfm
          listPlaylistsWithSong
          loopyLoop
          lyricsPlus
          phraseToPlaylist
          playNext
          playlistIcons
          playlistIntersection
          popupLyrics
          savePlaylists
          showQueueDuration
          shuffle # shuffle+
          skipStats
          songStats
          trashbin
          volumePercentage
        ];
      };
  };

  meta = {
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
