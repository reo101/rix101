{ inputs, lib, pkgs, config, ... }:
{
  imports = [
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-gpu-amd
    ./modules/disko.nix
    ./modules/network.nix
    ./modules/wireguard.nix
    ./modules/nginx.nix
    ./modules/jellyfin.nix
    ./modules/transmission.nix
    ./modules/mindustry.nix
    # ./modules/home-assistant
    ./modules/samba.nix
    # ./modules/steam.nix
    ./modules/ollama.nix
    ./modules/steam.nix
    ./modules/sunshine.nix
    # ./modules/photoprism.nix
    ./modules/immich.nix
    # ./modules/nextcloud.nix
    ./modules/paperless.nix
    ./modules/podman.nix
    ./modules/anki.nix
    ./modules/stirling-pdf.nix
    ./modules/taskwarrior.nix
    ./modules/nix-ld.nix
    ./modules/atuin.nix
    ./modules/monero.nix
    ./modules/syncyomi.nix
    ./modules/vaultwarden.nix
    ./modules/opencloud.nix
    ./modules/microvm.nix
    ./modules/home-assistant
  ];

  # services.kanidm = { };

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
    package = pkgs.nixVersions.latest;

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
    # FIXME: cannot deploy neovim-nightly
    #                               V neovim source
    #      > error: cannot add path '/nix/store/rhjznh5jdzdkzbnn0fhhvcf9rys0s59d-source' because it lacks a signature by a trusted key
    # neovim
  ];

  # NOTE: made with `mkpasswd -m sha-512`
  age.secrets."jeeves.user.password" = {
    rekeyFile = lib.repoSecret "home/jeeves/user/password.age";
    generator = {
      script = { pkgs, ... }: /* bash */ ''
        ${lib.getExe pkgs.mkpasswd} -m sha-512
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
          "input"
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

  security.sudo-rs = {
    enable = true; # !config.security.sudo.enable;
    inherit (config.security.sudo) extraRules;
  };
  security.sudo = {
    enable = false;
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
