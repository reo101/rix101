{ inputs, lib, pkgs, config, ... }:

{
  environment.packages = with pkgs; [ ];

  # Backup etc files instead of failing to activate generation if a file already exists in /etc
  environment.etcBackupExtension = ".bak";

  # Remove motd
  environment.motd = null;

  # # Set $EDITOR
  # environment.variables.EDITOR = "nvim";

  user.shell = "${pkgs.zsh}/bin/zsh";

  # Read the changelog before changing this value
  system.stateVersion = "22.11";

  nix.extraOptions = ''
    experimental-features = nix-command flakes recursive-nix
    keep-outputs = true
    keep-derivations = true
  '';

  nix.package = pkgs.nixVersions.monitored.latest;

  time.timeZone = "Europe/Sofia";

  terminal.font =
    let
      firacode = pkgs.nerdfonts.override {
        fonts = [ "FiraCode" ];
      };
      fontPath = "share/fonts/truetype/NerdFonts/FiraCodeNerdFontMono-Regular.ttf";
    in
    "${firacode}/${fontPath}";
}
