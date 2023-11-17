{ inputs, outputs, lib, pkgs, config, ... }:
{
  imports = [
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-gpu-amd
    (import ./disko.nix { inherit inputs outputs; })
    inputs.agenix.nixosModules.default
    ./network.nix
    ./wireguard.nix
    ./jellyfin.nix
  ];

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
    initrd.availableKernelModules = [
      "nvme"
    ];
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
  age.secrets."jeeves_password".file = ../../../../secrets/home/jeeves_password.age;

  users = {
    mutableUsers = true;
    users = {
      jeeves = {
        isNormalUser = true;
        shell = pkgs.zsh;
        hashedPasswordFile = config.age.secrets."jeeves_password".path;
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

  security.sudo.extraRules= [
    {
      users = [
        "jeeves"
      ];
      commands = [
        {
          command = "ALL" ;
          options= [ "NOPASSWD" ]; # "SETENV" # Adding the following could be a good idea
        }
      ];
    }
  ];

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
