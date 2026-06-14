{ lib, pkgs, config, ... }:
{
  services.tailscale = {
    enable = true;
  };
}
