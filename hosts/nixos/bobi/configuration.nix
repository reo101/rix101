# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ inputs, config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.hardware.nixosModules.apple-t2
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  networking.hostName = "bobi"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # age.secrets."home.wifi.env" = {
  #   rekeyFile = lib.repoSecret "home/wifi/env.age";
  # };
  networking.wireless = {
    iwd.enable = true;
    # secretsFile = config.age.secrets."home.wifi.env".path;
    # networks = {
    #   home = {
    #     ssid = "ext:HOME_WIFI_SSID";
    #     pskRaw = "ext:HOME_WIFI_PSK";
    #   };
    # };
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
        "maria"
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

  # Set your time zone.
  time.timeZone = "Europe/Sofia";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  services.pcscd.enable = true;

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.reo101 = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      tree
      neovim
      jujutsu
    ];
  };
  reo101.wayland.enable = true;

  programs.firefox.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    neovim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    gitFull
    wget
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # hardware.firmware = [
  #   (pkgs.stdenvNoCC.mkDerivation {
  #     name = "brcm-firmware";
  #
  #     buildCommand = ''
  #       dir="$out/lib/firmware"
  #       mkdir -p "$dir"
  #       cp -r ${./firmware}/* "$dir"
  #     '';
  #   })
  # ];

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?
}

