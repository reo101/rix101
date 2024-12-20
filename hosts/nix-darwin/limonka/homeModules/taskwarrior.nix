{ inputs, lib, pkgs, config, ... }:

{
  home.packages = with pkgs; [
    (taskopen.overrideAttrs (oldAttrs: {
      meta = oldAttrs.meta // {
        # NOTE: marked as `linux` only, but also works on `darwin`
        platforms = lib.platforms.unix;
      };
    }))
  ];

  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
    colorTheme = "dark-green-256";
    config = lib.rageImportEncrypted ./taskwarrior-config.nix.age;
  };
}
