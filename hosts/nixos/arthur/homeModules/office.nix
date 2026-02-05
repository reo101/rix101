{ lib, pkgs, ... }:

{
  home.packages = [
    pkgs.featherpad
    # Office Suite (`libreoffice-fresh` — `libreoffice` broken by nixpkgs#495635)
    pkgs.libreoffice-fresh
  ];

  programs.onlyoffice = {
    enable = true;
  };
}
