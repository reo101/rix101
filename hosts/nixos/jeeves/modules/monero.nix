{ lib, pkgs, config, ... }:
{
  services.monero = {
    enable = true;
    dataDir = "/data/monero";
  };
}
