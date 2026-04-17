{ inputs, pkgs, ... }:
let
  mapleFont = rec {
    package = pkgs.custom.maple-mono-custom;
    name = package.fontName;
  };
in
{
  rix101.wayland = {
    enable = true;
    user = "reo101";
    lock.command = [
      "noctalia-shell"
      "ipc"
      "call"
      "lockScreen"
      "lock"
    ];
    portal = {
      desktopNames = [ "niri" ];
      fileChooserBackend = "portty";
      portty.configText = ''
        exec = "@PORTTY_TERMINAL@"

        [file-chooser]
        exec = "@PORTTY_SESSION_HOLDER@"

        [file-chooser.bin]
        pick = "${pkgs.fd}/bin/fd --type f --type d --hidden --exclude .git . | ${pkgs.fzf}/bin/fzf --multi --height=100% --reverse --prompt='pick> ' | @PORTTY_SEL@ --stdin && @PORTTY_SUBMIT@"
      '';
    };
    niri.homeManagerModule = ../homeModules/niri;

    stylix = {
      colorscheme = inputs.nix-colors.colorSchemes.tokyo-night-dark;

      fonts.monospace = mapleFont;
      fonts.serif = mapleFont;
      fonts.sansSerif = mapleFont;
    };
  };
}
