{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) types;
  cfg = config.services.yubikey-touch-detector;
in
{
  options.services.yubikey-touch-detector = {
    enable = lib.mkEnableOption "a tool to detect when your YubiKey is waiting for a touch";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.yubikey-touch-detector;
      defaultText = "pkgs.yubikey-touch-detector";
      description = ''
        Package to use. Binary is expected to be called "yubikey-touch-detector".
      '';
    };

    socket.enable = lib.mkEnableOption "starting the process only when the socket is used";

    extraArgs = lib.mkOption {
      type = types.listOf types.str;
      default = [ "--libnotify" ];
      defaultText = lib.literalExpression ''[ "--libnotify" ]'';
      description = ''
        Extra arguments to pass to the tool. The arguments are not escaped.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Service description licensed under ISC
    # See https://github.com/maximbaz/yubikey-touch-detector/blob/c9fdff7163361d6323e2de0449026710cacbc08a/LICENSE
    # Author: Maxim Baz
    systemd.user.sockets.yubikey-touch-detector = lib.mkIf cfg.socket.enable {
      Unit.Description = "Unix socket activation for YubiKey touch detector service";
      Socket = {
        ListenFIFO = "%t/yubikey-touch-detector.sock";
        RemoveOnStop = true;
        SocketMode = "0660";
      };
      Install.WantedBy = [ "sockets.target" ];
    };

    # Same license thing for the description here
    systemd.user.services.yubikey-touch-detector = {
      Unit = {
        Description = "Detects when your YubiKey is waiting for a touch";
        Requires = lib.optionals cfg.socket.enable [ "yubikey-touch-detector.socket" ];
      };
      Service = {
        ExecStart = "${lib.getExe cfg.package} ${lib.escapeShellArgs cfg.extraArgs}";
        Environment = [ "PATH=${lib.makeBinPath [ pkgs.gnupg ]}" ];
        Restart = "on-failure";
        RestartSec = "1sec";
      };
      Install.Also = lib.optionals cfg.socket.enable [ "yubikey-touch-detector.socket" ];
      Install.WantedBy = [ "default.target" ];
    };
  };
}
