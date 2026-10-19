{ lib, pkgs, ... }:
{
  home.packages = [
    # (pkgs.balatro.override { src = null; })
    pkgs.balatro-mod-manager
    (lib.infuse pkgs.lutris {
      __input.extraPkgs.__assign = pkgs: [
        pkgs.vulkan-tools
        pkgs.winetricks
      ];
    })
  ];
}
