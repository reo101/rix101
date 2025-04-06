{ inputs, config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-apple-silicon.nixosModules.default
    ./modules/kanata.nix
  ];

  boot = {
    loader.systemd-boot.enable = true;
    # NOTE: `lib.mkForce`d to `false` because of `U-Boot` limitations
    # loader.efi.canTouchEfiVariables = true;
    extraModprobeConfig = ''
      options hid_apple fnmode=2
      options hid_apple iso_layout=0
    '';
    kernelParams = [
      "apple_dcp.unstable_edid=1"
      "apple_dcp.notch=1"
    ];
    binfmt = {
      emulatedSystems = [
        "x86_64-linux"
      ];
    };
  };

  hardware.bluetooth.enable = true;
  hardware.graphics.enable = true;
  # FIXME: `-Dlibgbm-external` fails to build
  # FIXME: `.drivers` does not nothing
  hardware.graphics.package = lib.mkForce (config.hardware.asahi.pkgs.mesa-asahi-edge.overrideAttrs (oldAttrs: {
    mesonFlags = lib.pipe oldAttrs.mesonFlags [
      (builtins.filter
        (flag:
          !(lib.hasPrefix "-Dlibgbm-external" flag)))
    ];
  }));

  hardware.asahi = {
    enable = true;
    # TODO: Git LFS
    # peripheralFirmwareDirectory = ./firmware;
    extractPeripheralFirmware = false;
    useExperimentalGPUDriver = true;
    setupAsahiSound = true;
    experimentalGPUInstallMode = "overlay";
  };

  services.upower = {
    enable = true;
  };
  services.batteryNotify = {
    enable = true;
    batteryName = "macsmc-battery";
  };

  programs.ydotool = {
    enable = true;
  };
  services.pcscd = {
    enable = true;
  };

  networking.hostName = "gomi";
  networking.wireless = {
    enable = false;
    iwd = {
      enable = true;
      settings = {
        General.EnableNetworkConfiguration = true;
      };
    };
  };
  networking.useNetworkd = true;
  systemd.network = {
    enable = true;
    wait-online = {
      enable = false;
      anyInterface = true;
    };
  };

  nix = {
    package = pkgs.nix-enraged.override { monitored = true; };

    settings = {
      trusted-users = [
        "root"
        "reo101"
      ];

      experimental-features = [
        "ca-derivations"        # Content-Addressable Derivations
        "dynamic-derivations"   # Dynamic Derivations
        "recursive-nix"         # Recursive Nix
        "flakes"                # Flakes and related commands
        "nix-command"           # Experimental Nix commands
        "auto-allocate-uids"    # Automatic allocation of UIDs
        "cgroups"               # Cgroup support
      ];

      # Deduplicate and optimize nix store
      auto-optimise-store = true;

      # Keep outputs and derivations
      keep-outputs = true;
      keep-derivations = true;
    };
  };

  time.timeZone = "Europe/Sofia";

  i18n.defaultLocale = "en_US.UTF-8";

  services.libinput.enable = true;

  programs.zsh.enable = true;
  users.users.reo101 = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      neovim
    ];
  };
  reo101.wayland.enable = true;

  programs.firefox.enable = true;

  services.openssh.enable = true;

  system.stateVersion = "25.05";
}
