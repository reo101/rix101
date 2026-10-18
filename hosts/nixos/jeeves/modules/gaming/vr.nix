{ config, lib, pkgs, ... }:
let
  adapterMACAddress = "90:30:d6:04:84:64";
  launcher = "${config.users.users.jeeves.home}/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor-launcher";
in
{
  # Steam configures the Frame's dedicated Wi-Fi link through NetworkManager.
  # Match this adapter by permanent MAC, independent of the USB port used.
  networking.networkmanager = {
    enable = true;
    unmanaged = [ "*,except:mac:${adapterMACAddress}" ];
    wifi.backend = "wpa_supplicant";
    dns = lib.mkForce "none";
    settings.main = {
      hostname-mode = "none";
      systemd-resolved = false;
    };
    connectionConfig = {
      "ipv4.route-metric" = 2048;
      "ipv6.route-metric" = 2048;
    };
  };
  networking.modemmanager.enable = false;

  # Existing home Wi-Fi definitions suppress NetworkManager's automatic
  # supplicant setup. Start a D-Bus daemon without claiming other interfaces.
  networking.wireless = {
    enable = true;
    autoDetectInterfaces = false;
    dbusControlled = true;
  };
  systemd.network.networks."05-steam-frame" = {
    matchConfig.PermanentMACAddress = adapterMACAddress;
    linkConfig.Unmanaged = true;
  };
  systemd.services.NetworkManager-wait-online.enable = false;

  # Bulgaria's regulatory domain permits the dedicated 6 GHz link. Apply on
  # boot and switch, including when cfg80211 was already loaded before switch.
  boot.kernelModules = [ "cfg80211" ];
  systemd.services.wireless-regulatory-domain = {
    description = "Set wireless regulatory domain to Bulgaria";
    wantedBy = [ "multi-user.target" ];
    before = [ "NetworkManager.service" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.iw}/bin/iw reg set BG";
    };
  };

  # OpenXR streaming to headsets running a compatible WiVRn client
  # https://github.com/WiVRn/WiVRn
  services.wivrn = {
    enable = true;
    openFirewall = true;
    # `jeeves` lingers, so the user service comes up on boot, not just login
    autoStart = true;
    # Let Steam/Proton pick up the WiVRn runtime while a headset is connected
    steam.importOXRRuntimes = true;
  };

  # SteamVR's setup prompt blocks startup in the headless session. Grant only
  # scheduling privileges, without Valve's problematic inheritable capability.
  systemd.services.steamvr-capabilities = {
    description = "Grant SteamVR compositor scheduling capability";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = launcher;
    serviceConfig.Type = "oneshot";
    script = ''
      launcher=${lib.escapeShellArg launcher}
      if [[ "$(${pkgs.libcap}/bin/getcap "$launcher")" != "$launcher cap_sys_nice=ep" ]]; then
        ${pkgs.libcap}/bin/setcap cap_sys_nice=ep "$launcher"
      fi
    '';
  };

  # Steam replaces the launcher on updates, clearing its file capabilities.
  systemd.paths.steamvr-capabilities = {
    description = "Watch for SteamVR compositor updates";
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = launcher;
  };

  # OpenVR -> OpenXR compat so Steam/Proton VR games run under WiVRn without
  # SteamVR. Runtime dir for launch options (`VR_OVERRIDE=$XRIZER_RUNTIME %command%`):
  # https://github.com/Supreeeme/xrizer
  environment = {
    systemPackages = [
      pkgs.xrizer
      pkgs.iw
    ];
    sessionVariables.XRIZER_RUNTIME = "${pkgs.xrizer}/lib/xrizer";
  };
}
