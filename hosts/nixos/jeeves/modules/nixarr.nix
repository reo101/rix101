{
  lib,
  pkgs,
  config,
  ...
}:
let
  lidarrQueueMaintainer = pkgs.writeShellApplication {
    name = "lidarr-queue-maintainer";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      pkgs.yq
    ];
    text = ''
      set -euo pipefail

      api_url="http://127.0.0.1:${builtins.toString config.nixarr.lidarr.port}/api/v1"
      config_xml="${config.nixarr.stateDir}/lidarr/config.xml"
      api_key="$(xq -r '.Config.ApiKey' < "$config_xml")"

      if [[ -z "$api_key" || "$api_key" == "null" ]]; then
        echo "failed to read Lidarr API key from $config_xml" >&2
        exit 1
      fi

      auth=(-H "X-Api-Key: $api_key")

      wait_for_lidarr() {
        for attempt in $(seq 1 60); do
          if curl -fsS --max-time 5 "''${auth[@]}" "$api_url/system/status" >/dev/null 2>&1; then
            return 0
          fi

          echo "waiting for Lidarr API at $api_url (attempt $attempt/60)"
          sleep 5
        done

        return 1
      }

      get_queue() {
        curl -fsS --max-time 30 "''${auth[@]}" \
          "$api_url/queue?page=1&pageSize=1000&sortDirection=ascending&sortKey=timeleft"
      }

      delete_queue_items() {
        local download_id="$1"
        local remove_from_client="$2"

        mapfile -t queue_ids < <(
          jq -r --arg download_id "$download_id" '
            .records[]
            | select(.downloadId == $download_id)
            | select(.trackedDownloadState == "importFailed")
            | select(.protocol == "SoulseekDownloadProtocol")
            | .id
          ' <<<"$queue_json"
        )

        for queue_id in "''${queue_ids[@]}"; do
          echo "removing Lidarr queue_id=$queue_id download_id=$download_id removeFromClient=$remove_from_client"
          curl -fsS -X DELETE "''${auth[@]}" \
            "$api_url/queue/$queue_id?removeFromClient=$remove_from_client" >/dev/null || true
          removed_queue_items=$((removed_queue_items + 1))
        done
      }

      run_manual_import() {
        local download_id="$1"
        local files_json="$2"
        local payload command_json command_id status_json command_status command_result

        payload="$(jq -cn --argjson files "$files_json" '{
          name: "ManualImport",
          importMode: "Auto",
          replaceExistingFiles: false,
          files: $files
        }')"

        if ! command_json="$(curl -fsS --max-time 30 -X POST "''${auth[@]}" -H 'Content-Type: application/json' --data "$payload" "$api_url/command")"; then
          echo "failed to submit manual import command for download_id=$download_id" >&2
          return 1
        fi
        command_id="$(jq -r '.id' <<<"$command_json")"
        command_status=""
        command_result="unknown"

        for _ in $(seq 1 60); do
          if ! status_json="$(curl -fsS --max-time 30 "''${auth[@]}" "$api_url/command/$command_id")"; then
            echo "failed to read manual import command status for download_id=$download_id command_id=$command_id" >&2
            return 1
          fi
          command_status="$(jq -r '.status' <<<"$status_json")"
          command_result="$(jq -r '.result' <<<"$status_json")"

          case "$command_status" in
            completed|failed|aborted|cancelled|orphaned)
              break
              ;;
          esac

          sleep 2
        done

        if [[ "$command_status" == "completed" && "$command_result" == "successful" ]]; then
          echo "manual import succeeded for download_id=$download_id"
          imported_downloads=$((imported_downloads + 1))
          return 0
        fi

        echo "manual import failed for download_id=$download_id (status=$command_status result=$command_result)" >&2
        return 1
      }

      if ! wait_for_lidarr; then
        echo "Lidarr API did not become available; skipping queue maintenance"
        exit 0
      fi

      if ! queue_json="$(get_queue)"; then
        echo "failed to read Lidarr queue; skipping queue maintenance" >&2
        exit 0
      fi

      mapfile -t download_ids < <(
        jq -r '
          .records[]
          | select(.trackedDownloadState == "importFailed")
          | select(.protocol == "SoulseekDownloadProtocol")
          | .downloadId
        ' <<<"$queue_json" | sort -u
      )

      if (( ''${#download_ids[@]} == 0 )); then
        echo "no failed Lidarr/Soulseek queue items to process"
        exit 0
      fi

      imported_downloads=0
      removed_queue_items=0
      skipped_downloads=0
      stale_downloads=0

      for download_id in "''${download_ids[@]}"; do
        echo "processing download_id=$download_id"

        if ! manual_json="$(curl -fsS --max-time 30 "''${auth[@]}" "$api_url/manualimport?downloadId=$download_id&filterExistingFiles=false&replaceExistingFiles=false")"; then
          echo "manual-import lookup failed for download_id=$download_id; removing stale Lidarr/slskd queue entry" >&2
          stale_downloads=$((stale_downloads + 1))
          delete_queue_items "$download_id" true
          continue
        fi

        files_json="$({
          jq -c '
            [
              .[]
              | ([.tracks[]? | select((.hasFile // false) | not) | .id] as $trackIds
              | select(($trackIds | length) > 0)
              | {
                  path,
                  artistId: .artist.id,
                  albumId: .album.id,
                  albumReleaseId,
                  trackIds: $trackIds,
                  quality,
                  indexerFlags,
                  downloadId,
                  disableReleaseSwitching
                })
            ]
          ' <<<"$manual_json"
        })"

        if jq -e 'length > 0' <<<"$files_json" >/dev/null; then
          if run_manual_import "$download_id" "$files_json"; then
            continue
          fi
          skipped_downloads=$((skipped_downloads + 1))
          continue
        fi

        # - No missing-track import candidates means either Lidarr already has
        #  all matched tracks, or this Soulseek result is unmatchable junk
        # - In both cases leaving it in the monitored download queue
        #   just creates a permanent warning loop
        # - Remove it from Lidarr and from `slskd`'s transfer list;
        #   this does not delete already-imported media files
        if jq -e 'all(.[]; ([.tracks[]? | select((.hasFile // false) | not) | .id] | length) == 0)' <<<"$manual_json" >/dev/null; then
          delete_queue_items "$download_id" true
          continue
        fi

        echo "not sure how to handle download_id=$download_id; leaving it alone" >&2
        skipped_downloads=$((skipped_downloads + 1))
      done

      echo "imported=$imported_downloads removed_queue_items=$removed_queue_items stale_downloads=$stale_downloads skipped=$skipped_downloads"
    '';
  };
in
{
  age.secrets."nixarr.prowlarr.rutracker-password" = {
    rekeyFile = lib.custom.repoSecret "home/jeeves/nixarr/rutracker-password.age";
    owner = "prowlarr";
    group = "prowlarr";
    mode = "0400";
  };

  environment.systemPackages = [
    pkgs.tremc
    lidarrQueueMaintainer
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
      settings-sync.transmission = {
        enable = true;
        config.fields.tvCategory = "sonarr";
      };
    };

    radarr = {
      enable = true;
      settings-sync.transmission = {
        enable = true;
        config.fields.movieCategory = "radarr";
      };
    };

    prowlarr = {
      enable = true;
      settings-sync = {
        enable-nixarr-apps = true;

        # Category ids are `Newznab`/`Torznab` categories exposed by Prowlarr
        # Reference: <https://newznab.readthedocs.io/en/latest/misc/api/#predefined-categories>
        # Exact supported categories can also be inspected with:
        #   `nixarr show-prowlarr-schemas indexer`
        sonarr.config.fields = {
          syncCategories = [
            # TV
            5000
            # TV/WEB-DL
            5010
            # TV/Foreign
            5020
            # TV/SD
            5030
            # TV/HD
            5040
            # TV/UHD
            5045
            # TV/Other
            5050
            # TV/x265
            5090
          ];
          animeSyncCategories = [
            # TV/Anime
            5070
          ];
          syncAnimeStandardFormatSearch = true;
        };
        radarr.config.fields.syncCategories = [
          # Movies
          2000
          # Movies/Foreign
          2010
          # Movies/Other
          2020
          # Movies/SD
          2030
          # Movies/HD
          2040
          # Movies/UHD
          2045
          # Movies/BluRay
          2050
          # Movies/3D
          2060
          # Movies/DVD
          2070
          # Movies/WEB-DL
          2080
          # Movies/x265
          2090
        ];
        lidarr.config.fields.syncCategories = [
          # Audio
          3000
          # Audio/MP3
          3010
          # Audio/Audiobook
          3030
          # Audio/Lossless
          3040
          # Audio/Other
          3050
          # Audio/Foreign
          3060
        ];

        indexers = [
          {
            name = "Nyaa.si";
            sort_name = "nyaa si";
            fields = {
              definitionFile = "nyaasi";
              prefer_magnet_links = true;
              # Nyaa Cardigann sort-order enum: 0 = ascending, 1 = descending
              type = 1;
            };
          }
          {
            name = "RuTracker.org";
            sort_name = "rutracker org";
            fields = {
              baseUrl = "https://rutracker.org/";
              username = "reo101";
              password.secret = config.age.secrets."nixarr.prowlarr.rutracker-password".path;
            };
          }
          {
            name = "Zamunda RIP";
            sort_name = "zamunda rip";
            fields.definitionFile = "zamundarip";
          }
        ];
      };
    };

    bazarr = {
      enable = true;
      settings-sync = {
        sonarr.enable = true;
        radarr.enable = true;
      };
    };

    lidarr = {
      enable = true;
      # NOTE: plugins are currently only available on Lidarr's nightly/prerelease channel
      package = pkgs.custom.lidarr-nightly;
    };

    seerr = {
      enable = true;
    };
  };

  services = {
    prowlarr.settings.auth.required = "DisabledForLocalAddresses";
    sonarr.settings.auth.required = "DisabledForLocalAddresses";
    radarr.settings.auth.required = "DisabledForLocalAddresses";
    lidarr.settings.auth.required = "DisabledForLocalAddresses";
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
  systemd.services = lib.mkMerge [
    (lib.genAttrs
      [
        "jellyfin"
        "transmission"
        "sonarr"
        "radarr"
        "prowlarr"
        "bazarr"
        "lidarr"
      ]
      (_: {
        serviceConfig.UMask = lib.mkForce "0002";
      })
    )
    {
      # Transmission 4.1.x under the current NixOS unit reaches the RPC listener
      # but never sends `systemd`'s ready notification, so `systemd` kills it
      # after `TimeoutStartSec` and Lidarr reports a bogus auth/client failure
      transmission.serviceConfig.Type = lib.mkForce "simple";

      # Prowlarr validates indexers against their upstream sites during sync.
      # Tracker outages should be logged but must not roll back a system switch.
      prowlarr-sync-config.serviceConfig.SuccessExitStatus = [ 1 ];

      lidarr-queue-maintainer = {
        description = "Import or clear stale Lidarr/Soulseek queue items";
        after = [ "lidarr.service" ];
        wants = [ "lidarr.service" ];
        serviceConfig = {
          ExecStart = lib.getExe lidarrQueueMaintainer;
          Type = "oneshot";
          User = "lidarr";
          Group = "media";
        };
      };
    }
  ];

  systemd.timers.lidarr-queue-maintainer = {
    description = "Periodically clean up stale Lidarr/Soulseek queue items";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15m";
      OnUnitActiveSec = "6h";
      Persistent = true;
    };
  };

  services.nginx.virtualHosts =
    let
      arrServices = [
        "sonarr"
        "radarr"
        "prowlarr"
        "bazarr"
        "lidarr"
        "seerr"
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
