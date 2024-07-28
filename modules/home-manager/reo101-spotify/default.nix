{ inputs, ... }:
{ lib, pkgs, config, ... }:

let
  cfg = config.reo101.spotify;

  inherit (lib)
    mkEnableOption mkOption types
    mkIf optionals optionalString
    mkMerge;
in
{
  imports =
    [
      inputs.spicetify-nix.homeManagerModules.default
    ];

  options =
    {
      reo101.spotify = {
        enable = mkEnableOption "reo101 spotify setup";
      };
    };

  config =
    mkIf cfg.enable {
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
            lastfm
            listPlaylistsWithSong
            loopyLoop
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
