{ lib, pkgs, ... }:
{
  home.packages = [
    # (pkgs.balatro.override { src = null; })
    pkgs.balatro-mod-manager
  ];
}
