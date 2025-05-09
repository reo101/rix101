{ inputs, lib, pkgs, config, ... }:

let
  # Home Assistant user and group
  cfg = {
    user = "hass";
    group = "hass";
  };

  # microvm networking
  vmName = "hass";
  vmMAC = "02:00:00:00:00:10";
  vmHostNum = 10;

  # MicroVM network (must match microvm.nix)
  microvm-network-cidr = "10.0.0.0/24";
  microvm-network-gateway = lib.net.cidr.host 1 microvm-network-cidr;

  vmIP = lib.net.cidr.host vmHostNum microvm-network-cidr;
  vmCidr = lib.net.cidr.hostCidr vmHostNum microvm-network-cidr;

  host-network-cidr = "192.168.1.0/24";
  host-network-gateway = lib.net.cidr.host 1 host-network-cidr;

  inherit (config.users.users.jeeves.openssh) authorizedKeys;

  # Local network devices to forward to the microvm
  forwardedIPs = lib.map (lib.flip lib.net.cidr.hostCidr host-network-cidr) [
    # Ledvance Lamp
    178
    # Air Purifier
    110
    # Samsung TV
    125
    # Chromecast
    116
  ];
in
{
  # Declarative Home Assistant MicroVM
  microvm.vms.${vmName} = {
    autostart = true;

    config = { config, pkgs, ... }: {
      imports = [
        inputs.microvm.nixosModules.microvm
        ./android.nix
        ./jokes.nix
      ];

      microvm = {
        hypervisor = "qemu";
        vcpu = 2;
        mem = builtins.floor (1.5 * 1024);

        interfaces = [
          {
            type = "tap";
            id = "vm-${vmName}";
            mac = vmMAC;
          }
        ];

        volumes = [
          {
            mountPoint = "/var/lib/hass";
            image = "/var/lib/microvms/${vmName}/hass.img";
            size = 8 * 1024;
          }
        ];

        shares = [
          {
            proto = "virtiofs";
            tag = "ro-store";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
          }
        ];

        socket = "control.socket";
      };

      # Basic system configuration
      networking.hostName = vmName;

      systemd.network = {
        enable = true;
        networks."10-lan" = {
          matchConfig.Driver = "virtio_net";
          addresses = [
            { Address = vmCidr; }
          ];
          routes = [
            { Gateway = microvm-network-gateway; }
          ];
          networkConfig.DNS = host-network-gateway;
        };
      };

      # Home Assistant configuration
      services.home-assistant = {
        enable = true;
        openFirewall = true;
        customComponents = [
          # Tuya-enabled appliances (LED lamps, power tool batteries)
          pkgs.home-assistant-custom-components.tuya_local
          # Philips AirPurifier devices
          pkgs.custom.hass-philips-airplus
        ];
        extraComponents = [
          # Enables a bunch of standard integrations (history, logbook, automation, etc.)
          "default_config"
          # Weather forecasts from Norwegian Meteorological Institute
          "met"
          # Browse and play internet radio stations
          "radio_browser"
          # ESP-based DIY sensors and devices (ESP8266/ESP32)
          "esphome"
          # Auto-discover devices on local network via mDNS/DNS-SD
          "zeroconf"
          # Auto-discover UPnP/SSDP devices (TVs, media players, etc.)
          "ssdp"
          # Companion app integration for iOS/Android (location, notifications)
          "mobile_app"
          # Samsung TVs
          "samsungtv"
          # OpenRGB-enabled devices
          "openrgb"
          # Android sleep tracking app
          "sleep_as_android"
          # Jellyfin
          "jellyfin"
          # Chromecast
          "cast"
        ];
        config = {
          default_config = { };
          homeassistant = {
            name = "Home";
            unit_system = "metric";
            time_zone = "Europe/Sofia";
          };
          http = {
            # WARN: deprecated option, listening on all interface by default now
            # server_host = "0.0.0.0";
            server_port = 8123;
            use_x_forwarded_for = true;
            trusted_proxies = [
              microvm-network-gateway
            ];
          };
          frontend = { };
          mobile_app = { };
          map = { };

          "automation ui" = "!include automations.yaml";
          "scene ui" = "!include scenes.yaml";
          "script ui" = "!include scripts.yaml";
        };
      };

      # Ensure correct ownership on mounted volume and config files exist
      systemd.tmpfiles.settings."home-assistant" = {
        "/var/lib/hass".d = {
          inherit (cfg) user group;
          mode = "0750";
        };
        "/var/lib/hass/automations.yaml".f = {
          inherit (cfg) user group;
          mode = "0644";
        };
        "/var/lib/hass/scripts.yaml".f = {
          inherit (cfg) user group;
          mode = "0644";
        };
        "/var/lib/hass/scenes.yaml".f = {
          inherit (cfg) user group;
          mode = "0644";
        };
      };

      # SSH for debugging
      services.openssh = {
        enable = true;
        settings = {
          PermitRootLogin = "yes";
          PasswordAuthentication = false;
        };
      };

      users.users.root.openssh = {
        inherit authorizedKeys;
      };

      system.stateVersion = "25.11";
    };
  };

  # Nginx reverse proxy for Home Assistant
  services.nginx.virtualHosts."hass.jeeves.reo101.xyz" = {
    forceSSL = true;
    useACMEHost = "jeeves.reo101.xyz";
    locations."/" = {
      proxyPass = "http://${vmIP}:${builtins.toString config.microvm.vms.${vmName}.config.config.services.home-assistant.config.http.server_port}";
      proxyWebsockets = true;
      extraConfig = /* nginx */ ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}
