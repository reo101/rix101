{ inputs, outputs, lib, config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [];

  # environment.darwinConfig = builtins.toString ./configuration.nix;

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  nix.package = pkgs.nix;

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true;  # default shell on catalina

  # Used for backwards compatibility, please read the changelog before changing.
  # > darwin-rebuild changelog
  system.stateVersion = 4;
}
