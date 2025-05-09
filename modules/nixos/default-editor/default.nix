{ lib, pkgs, config, ... }:

{
  programs.nano.enable = false;
  programs.neovim.enable = true;
}
