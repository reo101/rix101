{ inputs, lib, pkgs, config, ... }:

{
  home.packages = [
    (lib.infuse pkgs.taskopen {
      # NOTE: marked as `linux` only, but also works on `darwin`
      __output.meta.platforms.__assign = lib.platforms.unix;
    })
  ];

  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
    colorTheme = "dark-green-256";
    config = lib.rageImportEncryptedOrDefault ./taskwarrior-config.nix.age {};
  };
}
