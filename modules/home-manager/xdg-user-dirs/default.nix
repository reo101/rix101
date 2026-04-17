{ lib, config, ... }:

{
  config = lib.mkIf config.xdg.userDirs.enable {
    # Keep the pre-26.05 behavior explicit for the profiles that actually use
    # XDG user directories, instead of relying on the legacy default.
    xdg.userDirs.setSessionVariables = lib.mkDefault true;
  };
}
