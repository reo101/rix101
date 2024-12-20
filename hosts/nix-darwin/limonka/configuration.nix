{ inputs, lib, pkgs, config, ... }:

{
  imports = [
    inputs.self.nixosModules.substituters
    ./darwinModules/arrpc.nix
  ];

  environment.systemPackages = with pkgs; [ ];

  # environment.darwinConfig = builtins.toString ./configuration.nix;

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  nix = {
    # Ensure we can work with flakes
    # TODO: add to `README.md`
    # NOTE: run `sudo -i nix-env --uninstall nix` to uninstall the global `nix`
    package = pkgs.lix-monitored;

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
    };
  };

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true; # default shell on catalina

  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
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
