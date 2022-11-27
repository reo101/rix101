{ inputs, outputs, lib, config, pkgs, ... }:

{
  environment.packages = with pkgs; [];

  # Backup etc files instead of failing to activate generation if a file already exists in /etc
  environment.etcBackupExtension = ".bak";

  # Remove motd
  environment.motd = null;

  # # Set $EDITOR
  # environment.variables.EDITOR = "nvim";

  user.shell = "${pkgs.zsh}/bin/zsh";

  # Read the changelog before changing this value
  system.stateVersion = "22.05";

  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  time.timeZone = "Europe/Sofia";

  terminal.font =
    let
      firacode = pkgs.nerdfonts.override {
        fonts = [ "FiraCode" ];
      };
      fontPath = "share/fonts/truetype/NerdFonts/Fira Code Regular Nerd Font Complete Mono.ttf";
    in
      "${firacode}/${fontPath}";

  home-manager = {
    config = ./home.nix;
    backupFileExtension = "hm-bak";
    # useGlobalPkgs = true;

    extraSpecialArgs = { inherit inputs; };
  };
}
