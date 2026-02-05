{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  virtualisation.containers.enable = true;
  virtualisation = {
    docker = {
      enable = false;
    };
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };
  environment.systemPackages = with pkgs; [
    dive
    podman-tui
    podman-compose
  ];
}
