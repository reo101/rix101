{ lib, pkgs, config, ... }:
{
  environment.systemPackages = [
    pkgs.powertop
    pkgs.upower
    pkgs.acpid
  ];

  systemd.services.battery-charge-threshold = {
    description = "Set battery charge threshold";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "set-charge-threshold" ''
        test ! -e /sys/class/power_supply/BAT1/charge_control_end_threshold || echo 80 > /sys/class/power_supply/BAT1/charge_control_end_threshold
      '';
    };
  };

  services.upower = {
    enable = true;
    # HACK: broken battery gauge reports 0%; don't auto-hibernate until the installation of the new battery
    allowRiskyCriticalPowerAction = true;
    criticalPowerAction = "Ignore";
  };
}
