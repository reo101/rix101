{
  lib,
  pkgs,
  config,
  ...
}:
{
  environment.systemPackages = [
    pkgs.tremc
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = [
      pkgs.libva-vdpau-driver
      pkgs.libva1
      pkgs.vulkan-loader
      pkgs.vulkan-validation-layers
      pkgs.vulkan-extension-layer
    ];
  };

  nixarr = {
    enable = true;
    mediaDir = "/data/media";
    stateDir = "/data/.state/nixarr";

    jellyfin = {
      enable = true;
      openFirewall = true;
    };

    transmission = {
      enable = true;
      openFirewall = true;
      flood.enable = true;
      # TODO: `credentialsFile` for RPC password with agenix
      extraSettings = {
        rpc-bind-address = "0.0.0.0";
        rpc-whitelist = "127.0.0.1,192.168.*.*,10.100.0.*,*.local";
      };
    };

    sonarr = {
      enable = true;
    };

    radarr = {
      enable = true;
    };

    prowlarr = {
      enable = true;
    };

    bazarr = {
      enable = true;
    };

    readarr = {
      enable = true;
    };

    lidarr = {
      enable = true;
    };

    jellyseerr = {
      enable = true;
    };
  };

  # NOTE: (temporarily) block DNS requests to <zamunda.net>
  networking.extraHosts =
    let
      prefixes = [
        ""
        "www."
        "tracker."
      ];
    in
    lib.pipe prefixes [
      (lib.map (prefix: "127.0.0.1 ${prefix}zamunda.net"))
      (lib.concatStringsSep "\n")
    ];

  # NOTE: All *arr services and jellyfin share the `media` group.
  # UMask 0002 ensures created files are group-readable/writable,
  # so e.g. bazarr can read/write subs in dirs owned by jellyfin,
  # and radarr can manage metadata alongside jellyfin.
  # Jellyfin upstream defaults to 0077 — mkForce is needed to override.
  systemd.services =
    lib.genAttrs
      [
        "jellyfin"
        "transmission"
        "sonarr"
        "radarr"
        "prowlarr"
        "bazarr"
        "readarr"
        "lidarr"
      ]
      (_: {
        serviceConfig.UMask = lib.mkForce "0002";
      });

  services.nginx.virtualHosts =
    let
      arrServices = [
        "sonarr"
        "radarr"
        "prowlarr"
        "bazarr"
        "readarr"
        "lidarr"
        "jellyseerr"
      ];
      mkVhost = name: port: {
        "${name}.jeeves.reo101.xyz" = {
          forceSSL = true;
          useACMEHost = "jeeves.reo101.xyz";
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString port}";
            proxyWebsockets = true;
          };
        };
      };
    in
    lib.mkMerge (
      [
        (mkVhost "jellyfin" 8096)
        (mkVhost "transmission" config.services.transmission.settings.rpc-port)
      ]
      ++ map (arr: mkVhost arr config.nixarr.${arr}.port) arrServices
    );
}
