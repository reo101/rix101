{ inputs, outputs, lib, pkgs, config, ... }:

{
  environment.systemPackages = with pkgs; [ ];

  # environment.darwinConfig = builtins.toString ./configuration.nix;

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # nix = {
  #   # Ensure we can work with flakes
  #   package = pkgs.nixFlakes;
  #
  #   # This will add each flake input as a registry
  #   # To make nix3 commands consistent with your flake
  #   registry = lib.mapAttrs (_: value: { flake = value; }) inputs;
  #
  #   # This will additionally add your inputs to the system's legacy channels
  #   # Making legacy nix commands consistent as well, awesome!
  #   nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
  #
  #   settings = {
  #     # Enable flakes and new 'nix' command
  #     experimental-features = "nix-command flakes repl-flake";
  #     # Deduplicate and optimize nix store
  #     auto-optimise-store = true;
  #     # Keep outputs and derivations
  #     keep-outputs = true;
  #     keep-derivations = true;
  #   };
  # };

  nix.package = pkgs.nixFlakes;

  nix.extraOptions = ''
    experimental-features = nix-command flakes repl-flake
    keep-outputs = true
    keep-derivations = true
  '';

  # NIX_PATH =
  #   builtins.concatStringsSep
  #     ":"
  #     (lib.mapAttrsToList
  #       (name: input:
  #         "${name}=${input.url}?rev=${input.locked.rev}")
  #       inputs);

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true; # default shell on catalina

  # Fonts
  fonts.fontDir.enable = true;
  fonts.fonts = with pkgs; [
    (nerdfonts.override { fonts = [ "FiraCode" ]; })
  ];

  reo101 = {
    system = {
      enable = true;
    };
    brew = {
      enable = true;
    };
    yabai = {
      enable = true;
    };
  };

  # Keyboard
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToEscape = true;

  # Add ability to used TouchID for sudo authentication
  security.pam.enableSudoTouchIdAuth = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # > darwin-rebuild changelog
  system.stateVersion = 4;
}
