{ inputs, pkgs, ... }:
let
  mapleFont = rec {
    package = pkgs.custom.maple-mono-custom;
    name = package.fontName;
  };
in
{
  reo101.wayland = {
    enable = true;
    user = "reo101";
    lock.command = [
      "noctalia-shell"
      "ipc"
      "call"
      "lockScreen"
      "lock"
    ];
    niri.homeManagerModule = ../homeModules/niri;

    stylix = {
      colorscheme = inputs.nix-colors.colorSchemes.tokyo-night-dark;

      fonts.monospace = mapleFont;
      fonts.serif = mapleFont;
      fonts.sansSerif = mapleFont;
    };
  };
}
