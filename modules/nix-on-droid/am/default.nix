{ lib, pkgs, config, ... }:

{
  android-integration = {
    am.enable = true;
    termux-open.enable = true;
    termux-open-url.enable = true;
    termux-reload-settings.enable = true;
    termux-wake-unlock.enable = true;
    unsupported.enable = true;
    xdg-open.enable = true;
  };
}
