{ ... }:
{
  # Power management: hibernate on lid close
  services.logind.settings.Login = {
    HandleLidSwitch = "hibernate";
    HandleLidSwitchExternalPower = "suspend";
  };
}
