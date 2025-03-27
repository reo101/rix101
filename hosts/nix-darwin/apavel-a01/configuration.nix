{ inputs, lib, pkgs, config, ... }:

{
  environment.systemPackages = with pkgs; [ ];

  # environment.darwinConfig = builtins.toString ./configuration.nix;

  nix.package = pkgs.nix;

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true; # default shell on catalina

  # Fonts
  fonts.fontDir.enable = true;
  fonts.fonts = with pkgs; [
    nerd-fonts.fira-code
  ];

  # Keyboard
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToEscape = true;

  # Add ability to used TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # > darwin-rebuild changelog
  system.stateVersion = 4;
}
