{ package }:
{ config, lib, ... }:
let
  cfg = config.programs.septabee;
in
{
  options.programs.septabee = {
    enable = lib.mkEnableOption "Septabee with realtime scheduling capabilities";
    package = lib.mkOption {
      type = lib.types.package;
      default = package;
      defaultText = lib.literalExpression "pkgs.custom.septabee";
      description = "Septabee package to install and wrap.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # NixOS raises the capability into the ambient set, so the audio helper
    # inherits it even when Septabee launches it directly from the store.
    # Launch through PATH (or the desktop entry), not `nix run` or a store path.
    security.wrappers = lib.genAttrs [ "septabee" "septabee-sounds" ] (name: {
      source = "${cfg.package}/libexec/septabee/${name}";
      owner = "root";
      group = "root";
      permissions = "u+rx,g+rx,o+rx";
      capabilities = "cap_sys_nice+ep";
    });
  };
}
