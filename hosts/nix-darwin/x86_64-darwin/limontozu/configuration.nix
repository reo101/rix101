{ inputs, lib, pkgs, config, ... }:

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
  #     experimental-features = "nix-command flakes";
  #     # Deduplicate and optimize nix store
  #     auto-optimise-store = true;
  #     # Keep outputs and derivations
  #     keep-outputs = true;
  #     keep-derivations = true;
  #   };
  # };

  nix = {
    # Ensure we can work with flakes
    package = pkgs.nixVersions.stable;

    # extraOptions = ''
    #   # Enable flakes and new 'nix' command
    #   experimental-features = nix-command flakes
    #   # Allow building multiple derivations in parallel
    #   max-jobs = auto
    #   # Deduplicate and optimize nix store
    #   auto-optimise-store = true
    #   # Keep outputs and derivations
    #   keep-outputs = true
    #   keep-derivations = true
    # '';

    registry.nixpkgs.flake = inputs.nixpkgs;
    # registry =
    #   lib.mapAttrs'
    #     (name: value:
    #       {
    #         name = name;
    #         value = { flake = value; };
    #       })
    #     inputs;

    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = [
        # "nix-command"
        # "flakes"

        # "no-url-literals"       # Disabling URL literals
        "ca-derivations"        # Content-Addressable Derivations
        "recursive-nix"         # Recursive Nix
        "flakes"                # Flakes and related commands
        "nix-command"           # Experimental Nix commands
        "auto-allocate-uids"    # Automatic allocation of UIDs
        "cgroups"               # Cgroup support
        # "daemon-trust-override" # Overriding daemon trust settings
        # "dynamic-derivations"   # Dynamic derivation support
        # "discard-references"    # Discarding build output references
        "fetch-closure"         # builtins.fetchClosure
        "impure-derivations"    # Impure derivations
        "configurable-impure-env"
      ];

      # Allow building multiple derivations in parallel
      max-jobs = "auto";

      # Deduplicate and optimize nix store
      auto-optimise-store = false;

      # Keep outputs and derivations
      keep-outputs = true;
      keep-derivations = true;

      trusted-users = [
        "root"
        "pavelatanasov"
      ];

      # Add nix-community and rix101 cachix caches
      substituters = [
        "https://rix101.cachix.org"
        "https://nix-community.cachix.org"
        "https://lean4.cachix.org"
      ];
      trusted-public-keys = [
        "rix101.cachix.org-1:2u9ZGi93zY3hJXQyoHkNBZpJK+GiXQyYf9J5TLzCpFY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "lean4.cachix.org-1:mawtxSxcaiWE24xCXXgh3qnvlTkyU7evRRnGeAhD4Wk="
      ];
    };
  };

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
