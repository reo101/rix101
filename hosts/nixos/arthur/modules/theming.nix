{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.mint-themes
    pkgs.mint-y-icons
    pkgs.mint-cursor-themes
    pkgs.xfce4-whiskermenu-plugin
    pkgs.xfce4-pulseaudio-plugin
  ];

  fonts.packages = [
    pkgs.noto-fonts
  ];
}
