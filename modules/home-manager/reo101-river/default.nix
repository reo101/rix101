{ lib, pkgs, config, ... }:

with lib;
let
  cfg = config.reo101.river;
in
{
  imports =
    [
    ];

  options =
    {
      reo101.river = {
        enable = mkEnableOption "reo101 river setup";
        # swww = mkOption {
        #   type = types.boolean;
        #   description = "Enable swww (wallpaper daemon)";
        #   default = false;
        # };
      };
    };

  config =
    mkIf cfg.enable {
      home.packages = with pkgs;
        builtins.concatLists [
          [
            river
            # FIXME: does not build
            # swww # wallpaper deamon
            waybar # status bar
            xwayland
            wl-clipboard
            slurp # select regions from wayland
            grim # grap images from regions
            playerctl # music control
          ]
          # (optionals cfg.swww [
          #   swww
          # ])
        ];

      home.file.".config/river/init" = {
        executable = true;
        source = ./river;
      };

      home.file.".config/waybar/config" = {
        source = ./waybar;
      };

      home.file.".config/waybar/style.css" = {
        source = ./style.css;
      };

      # systemd.user.services."swww" = {
      #   Unit = {
      #     Description = "swww Daemon";
      #     PartOf = "graphical-session.target";
      #   };
      #   Service = {
      #     ExecStart = "${pkgs.swww}/bin/swww init --no-daemon";
      #     ExecStop = "${pkgs.swww}/bin/swww kill";
      #     Type = "simple";
      #     Restart = "always";
      #     RestartSec = 5;
      #   };
      #   Install = {
      #     WantedBy = [ "graphical-session.target" ];
      #   };
      #   # description = "Swww Deamon";
      #   # wantedBy = [ "graphical-session.target" ];
      #   # partOf = [ "graphical-session.target" ];
      #   # script = "${pkgs.swww}/bin/swww init --no-daemon";
      # };

      # services.swww = {
      #   enabled = true;
      # };

      # # dunst on wayland
      # services.wired = {
      #   enable = true;
      #   config = ./wired.ron;
      # };
    };

  meta = {
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
