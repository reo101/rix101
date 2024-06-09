{ inputs, outputs, lib, pkgs, config, ... }:
{
  imports = [
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-gpu-amd
    ./disko.nix
    inputs.ragenix.nixosModules.default
    inputs.agenix-rekey.nixosModules.default
    ./network.nix
    ./wireguard.nix
    ./jellyfin.nix
    ./mindustry.nix
    ./home-assistant
    ./samba.nix
    ./ollama.nix
  ];

  age.rekey = {
    hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPopSTZ81UyKp9JSljCLp+Syk51zacjh9fLteqxQ6/aB";
    masterIdentities = [ "${inputs.self}/secrets/privkey.age" ];
    storageMode = "derivation";
    # forceRekeyOnSystem = "aarch64-linux";
  };

  nixpkgs = {
    hostPlatform = "x86_64-linux";
    config = {
      allowUnfree = true;
    };
    overlays = [
    ];
  };

  networking.hostName = "jeeves";

  boot = {
    loader.systemd-boot.enable = true;
    kernelPackages = pkgs.linuxPackages_latest;
    binfmt.emulatedSystems = [ "aarch64-linux" ];
    initrd = {
      availableKernelModules = [
        "nvme"
      ];
      # kernelModules = [
      #   "amdgpu"
      # ];
    };
  };

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  nix = {
    registry =
      lib.mapAttrs
        (_: value: {
          flake = value;
        })
        inputs;

    nixPath =
      lib.mapAttrsToList
        (key: value:
          "${key}=${value.to.path}")
        config.nix.registry;

    settings = {
      trusted-users = [
        "root"
        "jeeves"
      ];

      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
    };
  };

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    git
    neovim
  ];

  # NOTE: made with `mkpasswd -m sha-516`
  age.secrets."jeeves.user.password" = {
    rekeyFile = "${inputs.self}/secrets/home/jeeves/user/password.age";
    generator = {
      script = { pkgs, ... }: ''
        ${pkgs.mkpasswd}/bin/mkpasswd -m sha-516
      '';
    };
  };

  users = {
    mutableUsers = true;
    users = {
      jeeves = {
        isNormalUser = true;
        shell = pkgs.zsh;
        hashedPasswordFile = config.age.secrets."jeeves.user.password".path;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBj8ZGcvI80WrJWV+dNy1a3L973ydSNqtwcVHzurDUaW (none)"
        ];
        extraGroups = [
          "wheel"
          "networkmanager"
          "audio"
          "docker"
          "transmission"
        ];
      };
    };
  };

  # reo101.jellyfin = {
  #   enable = true;
  #   image = "docker.io/jellyfin/jellyfin:latest";
  #   volumes = [
  #     "/var/cache/jellyfin/config:/config"
  #     "/var/cache/jellyfin/cache:/cache"
  #     "/var/log/jellyfin:/log"
  #     "/data/media/jellyfin:/media:ro"
  #   ];
  #   ports = [
  #     "8096:8096"
  #   ];
  # };

  # security.sudo-rs = {
  #   enable = !config.security.sudo.enable;
  #   inherit (config.security.sudo) extraRules;
  # };
  security.sudo = {
    enable = true;
    extraRules = [
      {
        users = [
          "jeeves"
        ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ]; # "SETENV" # Adding the following could be a good idea
          }
        ];
      }
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  boot.plymouth = {
    enable = true;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.05";
}
