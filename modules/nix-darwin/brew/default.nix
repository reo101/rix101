{ lib, pkgs, config, ... }:

with lib;
let
  cfg = config.reo101.brew;
in
{
  imports = [
  ];

  options = {
    reo101.brew = {
      enable = mkEnableOption "reo101 brew config";
    };
  };

  config = mkIf cfg.enable {
    # Requires Homebrew to be installed
    system.activationScripts.preUserActivation.text = ''
      if ! xcode-select --version 2>/dev/null; then
        $DRY_RUN_CMD xcode-select --install
      fi
      if ! /usr/local/bin/brew --version 2>/dev/null; then
        $DRY_RUN_CMD /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
    '';

    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = false; # Don't update during rebuild
        upgrade = true;
        cleanup = "zap"; # Uninstall all programs not declared
      };
      global = {
        brewfile = true; # Run brew bundle from anywhere
        lockfiles = false; # Don't save lockfile (since running from anywhere)
      };
      taps = [
        "homebrew/core"
        "homebrew/cask"
        "homebrew/cask-fonts"
        "homebrew/cask-drivers"
        "homebrew/services"
        "cmacrae/formulae"
        "FelixKratz/formulae"
        "jorgelbg/tap"
      ];
      brews = [
        "libusb"
        "switchaudio-osx"
        "pinentry-touchid"
      ];
      casks = [
        "android-platform-tools"
        "docker"
        "font-fira-code-nerd-font"
        "karabiner-elements"
        "scroll-reverser"
        "sf-symbols"
        # "slack"
        "spotify"
        "xquartz"
      ];
      extraConfig = ''
        # brew "xorpse/formulae/brew", args: ["HEAD"]
        cask_args appdir: "~/Applications"
      '';
    };
  };

  meta = {
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
