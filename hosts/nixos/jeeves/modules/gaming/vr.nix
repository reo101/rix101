{ pkgs, ... }:
{
  # OpenXR streaming to standalone headsets (Quest, Pico, Steam Frame ...)
  # https://github.com/WiVRn/WiVRn
  services.wivrn = {
    enable = true;
    openFirewall = true;
    # `jeeves` lingers, so the user service comes up on boot, not just login
    autoStart = true;
    # Let Steam/Proton pick up the WiVRn runtime while a headset is connected
    steam.importOXRRuntimes = true;
  };

  # OpenVR -> OpenXR compat so Steam/Proton VR games run under WiVRn without
  # SteamVR. Runtime dir for launch options (`VR_OVERRIDE=$XRIZER_RUNTIME %command%`):
  # https://github.com/Supreeeme/xrizer
  environment = {
    systemPackages = [ pkgs.xrizer ];
    sessionVariables.XRIZER_RUNTIME = "${pkgs.xrizer}/lib/xrizer";
  };
}
