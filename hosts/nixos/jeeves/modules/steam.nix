{ inputs, lib, pkgs, config, ... }:
{
  imports = [
    inputs.self.nixosModules.steam
    inputs.steamlesslink.nixosModules.steamless-link-host
  ];

  environment.systemPackages = [
    pkgs.mangohud
    pkgs.protonup-ng
    pkgs.r2modman
    pkgs.protontricks
  ];

  services.steamless-link-host = {
    enable = true;
    user = "jeeves";
    listenHost = "0.0.0.0";
    listenPort = 3244;
    iroh.enable = true;
  };

  # Raw controller traffic is unauthenticated: admit it only from home.
  networking.firewall = let
    homeCidr = "192.168.1.0/24";
    port = builtins.toString config.services.steamless-link-host.listenPort;
  in {
    interfaces.wg0.allowedTCPPorts = [ 3244 ];
    extraCommands = /* bash */ ''
      ${lib.getExe pkgs.iptables} -A INPUT -s ${homeCidr} -p tcp --dport ${port} -j ACCEPT
    '';
    extraStopCommands = /* bash */ ''
      ${lib.getExe pkgs.iptables} -D INPUT -s ${homeCidr} -p tcp --dport ${port} -j ACCEPT 2>/dev/null || true
    '';
  };

  # Steam
  rix101.steam.extest = {
    enable = true;
    steamPackage = pkgs.millennium-steam;
    users = [ "jeeves" ];
  };

  hardware.steam-hardware.enable = true;

  # `hardware.steam-hardware` installs Valve's rules and loads `uinput`.
  # `jeeves` has no active local seat, so repeat the Valve matches with
  # `GROUP="input"`; `99-local.rules` runs after the upstream package rules.
  services.udev.extraRules = lib.concatStringsSep "\n" [
    ''SUBSYSTEMS=="usb", ATTRS{idVendor}=="28de", MODE="0660", GROUP="input", TAG+="uaccess"''
    ''KERNEL=="hidraw*", ATTRS{idVendor}=="28de", MODE="0660", GROUP="input", TAG+="uaccess"''

    # Steam Controller Puck normal firmware/update serial endpoint
    ''ACTION=="add|change", SUBSYSTEM=="tty", ATTRS{idVendor}=="28de", ATTRS{idProduct}=="1304", MODE="0660", GROUP="input", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"''

    # Steam Controller Puck bootloader firmware flashing serial endpoint
    ''ACTION=="add|change", SUBSYSTEM=="tty", ATTRS{idVendor}=="28de", ATTRS{idProduct}=="1007", MODE="0660", GROUP="input", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"''

    # Steam Controller normal wired USB mode
    ''ACTION=="add|change", SUBSYSTEM=="tty", ATTRS{idVendor}=="28de", ATTRS{idProduct}=="1302", MODE="0660", GROUP="input", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"''

    # Steam Controller bootloader firmware flashing serial endpoint
    ''ACTION=="add|change", SUBSYSTEM=="tty", ATTRS{idVendor}=="28de", ATTRS{idProduct}=="1005", MODE="0660", GROUP="input", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"''
  ];

  programs.steam = {
    enable = true;
    protontricks.enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  # Proton
  environment.sessionVariables = {
    # NOTE: run `protonup -d "~/.steam/root/compatibilitytools.d"`
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "${config.home-manager.users.jeeves.home.homeDirectory}/.steam/root/compatibilitytools.d";
  };

  # Core graphics
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };

    amdgpu = {
      opencl = {
        enable = true;
      };
    };
  };

  # Compositing and optimisation
  programs.gamescope = {
    enable = true;
    capSysNice = false;
  };
  programs.gamemode = {
    enable = true;
  };

  # Better scheduling for gaming
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
  };

  # VR
  programs.alvr = {
    enable = true;
    openFirewall = true;
  };

  # Sound
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse = {
      enable = true;
    };
    jack = {
      enable = true;
    };
  };

  services.dbus = {
    enable = true;
    packages = [ pkgs.dconf ];
  };
}
