{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
}:

buildHomeAssistantComponent rec {
  owner = "wessamlauf";
  domain = "frosted_glass_manager";
  version = "1.3.0.1";

  src = fetchFromGitHub {
    inherit owner;
    repo = "frosted-glass-manager";
    tag = "v${version}";
    hash = "sha256-ye2/GR6b/+BpVMDnFDH5m/CydxI1tqDBSSs9lX9YtB0=";
  };

  meta = with lib; {
    description = "Customize Frosted Glass theme colors and backgrounds via Home Assistant UI";
    homepage = "https://github.com/wessamlauf/frosted-glass-manager";
    changelog = "https://github.com/wessamlauf/frosted-glass-manager/releases/tag/v${version}";
    license = licenses.unfree; # No license specified
    maintainers = with maintainers; [ reo101 ];
  };
}
