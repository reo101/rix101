{
  inputs,
  lib,
  pkgs,
  utils,
  ...
}:
let
  storageWebhookId = "b490d49b-e9d2-4a90-bbb1-4e9909507904";

  storageNotify = pkgs.writeShellApplication {
    name = "jeeves-storage-notify";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.systemd
      pkgs.util-linux
    ];
    text = ''
      title="''${1:?notification title is required}"
      message="''${2:?notification message is required}"

      payload=$(jq --compact-output --null-input \
        --arg title "$title" \
        --arg message "$message" \
        '{ title: $title, message: $message }')
      if ! curl --fail --silent --show-error \
        --connect-timeout 3 \
        --max-time 10 \
        --header 'Content-Type: application/json' \
        --data "$payload" \
        'http://10.0.0.10:8123/api/webhook/${storageWebhookId}'; then
        printf 'Home Assistant storage notification failed: %s: %s\n' \
          "$title" "$message" \
          | systemd-cat --identifier=jeeves-storage-monitor --priority=err
        exit 1
      fi

      printf '%s: %s\n' "$title" "$message" \
        | systemd-cat --identifier=jeeves-storage-monitor --priority=warning
      printf '%s: %s\n' "$title" "$message" | wall --nobanner 2>/dev/null || true
    '';
  };

  smartNotify = pkgs.writeShellApplication {
    name = "jeeves-smart-notify";
    text = ''
      message="''${SMARTD_FULLMESSAGE:-''${SMARTD_MESSAGE:-Unknown SMART error}}"
      ${lib.getExe storageNotify} \
        "SMART alert for ''${SMARTD_DEVICESTRING:-unknown disk}" \
        "$message"
    '';
  };

  mdHealthCheck = pkgs.writeShellApplication {
    name = "jeeves-md-health-check";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.mdadm
    ];
    text = ''
      # The legacy state did not distinguish a delivered webhook from a failed
      # attempt. Drop it and persist only confirmed delivery from now on.
      rm -f /var/lib/jeeves-storage-monitor/md-tank-degraded
      state_file=/var/lib/jeeves-storage-monitor/md-tank-degraded-notified

      if details=$(mdadm --detail --test /dev/md/tank 2>&1); then
        if [[ -e "$state_file" ]]; then
          if ${lib.getExe storageNotify} \
            'Jeeves RAID recovered' \
            '/dev/md/tank reports all expected members active again.'; then
            rm -f "$state_file"
          fi
        fi
      else
        status=$?
        details=$(mdadm --detail /dev/md/tank 2>&1 || printf '%s' "$details")
        if [[ ! -e "$state_file" ]]; then
          if ${lib.getExe storageNotify} \
            'Jeeves RAID degraded' \
            "$details"; then
            touch "$state_file"
          fi
        fi
        printf '%s\n' "$details" >&2
        exit "$status"
      fi
    '';
  };

  diskSpaceCheck = pkgs.writeShellApplication {
    name = "jeeves-disk-space-check";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      check_mount() {
        local label="$1"
        local mount_point="$2"
        local legacy_state_file="/var/lib/jeeves-storage-monitor/space-$label"
        local state_file="$legacy_state_file-notified"
        local usage

        # The legacy state may represent a failed webhook attempt.
        rm -f "$legacy_state_file"
        usage=$(df --output=pcent "$mount_point" | tail -n 1 | tr -cd '0-9')
        if (( usage >= 85 )); then
          if [[ ! -e "$state_file" ]]; then
            if ${lib.getExe storageNotify} \
              "Jeeves disk space at $usage%" \
              "$mount_point has crossed the 85% usage threshold."; then
              touch "$state_file"
            fi
          fi
          return 0
        elif (( usage <= 80 )) && [[ -e "$state_file" ]]; then
          if ${lib.getExe storageNotify} \
            'Jeeves disk space recovered' \
            "$mount_point is back down to $usage% usage."; then
            rm -f "$state_file"
          fi
        fi
        return 0
      }

      failed=0
      check_mount root / || failed=1
      check_mount tank /data || failed=1
      exit "$failed"
    '';
  };
in
{
  imports = [
    inputs.disko.nixosModules.disko
  ];

  environment.systemPackages = with pkgs; [
    # `statfs` for btrfs commands
    gocryptfs
  ];

  # If on installer
  disko.enableConfig = true;

  # `head -c 8 /etc/machine-id`
  networking.hostId = "1418566e";

  # NOTE: needed for mounting `/key` (for LUKS)
  boot.initrd.kernelModules = [
    "uas"
    "ext4"
  ];

  # HACK: `mdadm: No mail address or alert command - not monitoring.`
  boot.swraid.mdadmConf = "MAILADDR root";

  nix.gc = {
    automatic = true;
    dates = "Sun 05:00";
    randomizedDelaySec = "1h";
    options = "--delete-older-than 30d";
  };

  services.btrfs.autoScrub = {
    enable = true;
    # `/home`, `/nix`, and `/data` are subvolumes of the same filesystem.
    fileSystems = [
      "/"
      "/data"
    ];
    interval = "monthly";
  };

  services.smartd = {
    enable = true;
    autodetect = false;
    defaults.monitored = "-a -o on -S on -n standby,q -W 4,45,50 -m <nomailer> -M exec ${lib.getExe smartNotify}";
    devices = [
      {
        device = "/dev/disk/by-id/ata-WDC_WD8003FFBX-68B9AN0_VYJB5TUM";
        # Monitor the detached member while tolerating its physical removal, but
        # do not schedule more self-tests after its extended test stopped progressing.
        options = "-d removable";
      }
      {
        device = "/dev/disk/by-id/ata-WDC_WD8003FFBX-68B9AN0_VYHZTWSM";
        options = "-s (S/../.././02|L/../02/./03)";
      }
    ];
    notifications = {
      mail.enable = false;
      wall.enable = false;
      x11.enable = false;
    };
  };

  systemd.services = {
    jeeves-md-health-check = {
      description = "Check Jeeves mdraid health";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe mdHealthCheck;
        # A degraded array is reported through `storageNotify`, not deploy-rs
        SuccessExitStatus = [ 1 ];
        StateDirectory = "jeeves-storage-monitor";
      };
    };
    jeeves-disk-space-check = {
      description = "Check Jeeves filesystem usage";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe diskSpaceCheck;
        StateDirectory = "jeeves-storage-monitor";
      };
    };
  };

  systemd.timers = {
    jeeves-md-health-check = {
      description = "Periodically check Jeeves mdraid health";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        RandomizedDelaySec = "5m";
        Persistent = true;
      };
    };
    jeeves-disk-space-check = {
      description = "Periodically check Jeeves filesystem usage";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };
  };

  # HACK: for troubleshooting
  boot.initrd.systemd.emergencyAccess = true;

  # LUKS key files live on a separate USB/ext4 partition. In systemd stage 1,
  # mount the USB, copy the keys into initrd tmpfs, then let cryptsetup use the
  # tmpfs copies. This avoids cryptsetup depending on /key, so /key can be
  # unmounted before switch-root and the USB can be removed after boot.
  boot.initrd.systemd.mounts = [
    {
      description = "Mount LUKS key partition";
      what = "/dev/disk/by-partlabel/key";
      where = "/key";
      type = "ext4";
      options = "ro";
      wantedBy = [ "copy-luks-keys.service" ];
      before = [
        "copy-luks-keys.service"
        "initrd-switch-root.target"
        "shutdown.target"
      ];
      wants = [ "systemd-udev-trigger.service" ];
      after = [
        "systemd-modules-load.service"
        "systemd-udev-trigger.service"
      ];
      conflicts = [
        "initrd-switch-root.target"
        "shutdown.target"
      ];
      unitConfig.DefaultDependencies = "no";
    }
  ];

  boot.initrd.systemd.services.copy-luks-keys =
    let
      cryptsetupServices = lib.map (name: "systemd-cryptsetup@${utils.escapeSystemdPath name}.service") [
        "root"
        "tank"
      ];
    in
    {
      description = "Copy LUKS keys into initrd tmpfs";
      wantedBy = cryptsetupServices;
      requires = [ "key.mount" ];
      after = [ "key.mount" ];
      before = cryptsetupServices;
      conflicts = [
        "initrd-switch-root.target"
        "shutdown.target"
      ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig = {
        Type = "oneshot";
        StandardOutput = "journal+console";
        StandardError = "journal+console";
      };
      path = [ pkgs.coreutils ];
      script = ''
        install -d -m 0700 /run/cryptsetup-keys.d
        install -m 0400 /key/root /run/cryptsetup-keys.d/root
        install -m 0400 /key/tank /run/cryptsetup-keys.d/tank
        echo 'Copied LUKS keys from /key into initrd tmpfs'
      '';
    };

  disko = {
    devices = {
      disk = {
        # NOTE: we could do this to setup a usb for the keys
        #       but disko overrides it with no option of ignoring when partitioning
        #       (i.e. tell disko to only use this only for decalartion)
        # key = {
        #   type = "disk";
        #   device = "/dev/disk/by-id/usb-USB2.0_Flash_Disk_1000000000001D8B-0";
        #   content = {
        #     type = "gpt";
        #     partitions = {
        #       key = {
        #         label = "key";
        #         size = "100%";
        #         content = {
        #           type = "filesystem";
        #           format = "ext4";
        #           mountpoint = "/key";
        #         };
        #       };
        #     };
        #   };
        # };
        ssd1 = {
          type = "disk";
          device = "/dev/disk/by-id/nvme-eui.e8238fa6bf530001001b448b4ebde3a6";
          content = {
            type = "gpt";
            partitions = {
              boot = {
                label = "boot_mbr";
                size = "1M";
                type = "EF02"; # for grub MBR
                priority = 1;
              };
              ESP = {
                label = "boot";
                size = "512M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                };
                priority = 2;
              };
              root = {
                label = "root";
                size = "100%";
                content = {
                  type = "luks";
                  name = "root";
                  extraOpenArgs = [ ];
                  settings = {
                    keyFile = "/run/cryptsetup-keys.d/root";
                    crypttabExtraOpts = [ "x-initrd.attach" ];
                  };
                  content = {
                    type = "btrfs";
                    extraArgs = [ "-f" ]; # Override existing partition
                    subvolumes = {
                      "/root" = {
                        mountpoint = "/";
                      };
                    };
                  };
                };
                priority = 3;
              };
            };
          };
        };
        hdd1 = {
          type = "disk";
          device = "/dev/disk/by-id/ata-WDC_WD8003FFBX-68B9AN0_VYJB5TUM";
          content = {
            type = "gpt";
            partitions = {
              mdadm = {
                label = "hdd1";
                size = "100%";
                content = {
                  type = "mdraid";
                  name = "tank";
                };
              };
            };
          };
        };
        hdd2 = {
          type = "disk";
          device = "/dev/disk/by-id/ata-WDC_WD8003FFBX-68B9AN0_VYHZTWSM";
          content = {
            type = "gpt";
            partitions = {
              mdadm = {
                label = "hdd2";
                size = "100%";
                content = {
                  type = "mdraid";
                  name = "tank";
                };
              };
            };
          };
        };
      };
      mdadm = {
        tank = {
          type = "mdadm";
          level = 1;
          content = {
            type = "luks";
            name = "tank";
            extraOpenArgs = [ "--allow-discards" ];
            settings = {
              keyFile = "/run/cryptsetup-keys.d/tank";
              crypttabExtraOpts = [ "x-initrd.attach" ];
            };
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ]; # Override existing partition
              subvolumes = {
                "/home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "compress=zstd"
                  ];
                };
                "/nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "/data" = {
                  mountpoint = "/data";
                  mountOptions = [
                    "compress=zstd"
                  ];
                };
                "/data/.state" = { };
                "/data/media" = { };
                "/data/torrents" = { };
                "/data/media/jellyfin" = { };
                "/data/samba" = { };
              };
            };
          };
        };
      };
    };
  };
}
