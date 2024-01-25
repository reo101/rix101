{ lib, pkgs, config, ... }:

with lib;
let
  cfg = config.reo101.mindustry;
in
{
  imports = [
  ];

  options = {
    reo101.mindustry = {
      enable = mkEnableOption "reo101 Mindustry config";
      version = mkOption {
        type = types.str;
        default = "146";
        description = ''
          Game version to run
        '';
      };
      # jarUrl = mkOption {
      #   type = types.str;
      #   default = "https://github.com/Anuken/Mindustry/releases/download/v${cfg.version}/Mindustry.jar";
      #   description = ''
      #     URL of the game server jar
      #   '';
      # };
      # jarSha256 = mkOption {
      #   type = types.str;
      #   default = "sha256-OrDkbDy9yGNSm6BegEhH7wDj29tFZ7XCfF5tzgcbk/k=";
      #   description = ''
      #     sha256 of the game server jar
      #   '';
      #   };
      # java = mkOption {
      #   type = types.package;
      #   default = pkgs.zulu17;
      #   defaultText = "pkgs.zulu17";
      #   description = ''
      #     Java package used to run the game server jar
      #   '';
      # };
      mindustry-server = mkOption {
        type = types.package;
        default = pkgs.mindustry-server;
        defaultText = "pkgs.mindustry-server";
        description = ''
          Package providing the `/bin/mindustry-server` binary
        '';
      };
      port = mkOption {
        type = types.port;
        default = 6567;
        description = ''
          Port to run the game server on
        '';
      };
      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to open the game port to the firewall
        '';
      };
    };
  };

  config = mkIf cfg.enable (
    let
      # mindustryJar = builtins.fetchurl {
      #   url = cfg.jarUrl;
      #   sha256 = cfg.jarSha256;
      # };
      # mindustryCmd = "${cfg.java}/bin/java -jar ${mindustryJar}";
      mindustryConfig = lib.concatStringsSep "," [
        ("startCommands " + lib.concatStringsSep "," [
          "config port ${builtins.toString cfg.port}"
          "config logging false"
        ])
      ];
      mindustryCmd = "${cfg.mindustry-server}/bin/mindustry-server ${mindustryConfig}";
    in
    {
      # FIXME: set log path

      # systemd.services.mindustry = 
      #   wantedBy = [ "multi-user.target" ];
      #   after = [ "network.target" ];
      #   description = "Start a Mindustry server instance";
      #   serviceConfig = {
      #     User = "jeeves";
      #     # ExecStart = ''${pkgs.screen}/bin/screen -dmS mindustry ${mindustryCmd}'';
      #     # ExecStop = ''${pkgs.screen}/bin/screen -S mindustry -X quit'';
      #     # Restart = "on-failure";
      #     # RestartSec = "5s";
      #     Type = "forking";
      #     ExecStart = ''${mindustryCmd}'';
      #   };
      # };

      environment.systemPackages = with pkgs; [
        mindustry-server
      ];

      networking.firewall =
        lib.pipe
          [ "TCP" "UDP" ]
          [
            (builtins.map
              (protocol:
                lib.nameValuePair
                  "allowed${protocol}Ports"
                  [ cfg.port ]))
            builtins.listToAttrs
          ];

      # networking.firewall.allowedTCPPorts = [cfg.port];
      # networking.firewall.allowedUDPPorts = [cfg.port];
    }
  );

  meta = {
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
