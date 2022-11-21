{ inputs, outputs, lib, config, pkgs, ... }:

{
  environment.packages = with pkgs; [];

  # Backup etc files instead of failing to activate generation if a file already exists in /etc
  environment.etcBackupExtension = ".bak";

  # Remove motd
  environment.motd = null;

  # # Set $EDITOR
  # environment.variables.EDITOR = "nvim";

  # Read the changelog before changing this value
  system.stateVersion = "22.05";

  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  time.timeZone = "Europe/Sofia";

  home-manager = {
    config = ./home.nix;
    backupFileExtension = "hm-bak";
    # useGlobalPkgs = true;

    extraSpecialArgs = { inherit inputs; };
  };
}
