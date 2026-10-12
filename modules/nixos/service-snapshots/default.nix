{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rix101.serviceSnapshots;
  groups = cfg.groups;
  socketDirectories =
    config.services.postgresql.settings.unix_socket_directories or "/run/postgresql";
  sourcePaths = group: (lib.attrNames group.subvolumes) ++ [ group.stateDirectory ];
  snapshotDirectory =
    group: path:
    lib.pipe (sourcePaths group) [
      (lib.filter (source: source == path || lib.hasPrefix "${source}/" path))
      (lib.sort (a: b: lib.stringLength a < lib.stringLength b))
      lib.head
      lib.dirOf
      (parent: "${parent}/.service-snapshots")
    ];
  snapshotName =
    name: path: "${name}-${lib.baseNameOf path}-${lib.substring 0 12 (lib.hashString "sha256" path)}";
  snapshotConfiguration = name: group: /* bash */ ''
    declare -A snapshot_directories=(
      ${lib.concatMapStringsSep "\n" (
        path: /* bash */ "[${lib.escapeShellArg path}]=${lib.escapeShellArg (snapshotDirectory group path)}"
      ) (sourcePaths group)}
    )
    declare -A snapshot_names=(
      ${lib.concatMapStringsSep "\n" (
        path: /* bash */ "[${lib.escapeShellArg path}]=${lib.escapeShellArg (snapshotName name path)}"
      ) (sourcePaths group)}
    )
  '';
  instanceName = name: "service-snapshots-${name}";
  allUnits = lib.pipe groups [
    lib.attrValues
    (lib.concatMap (group: group.units))
  ];
  allSources = lib.pipe groups [
    lib.attrValues
    (lib.concatMap sourcePaths)
  ];
  validPath =
    path:
    let
      subpath = lib.removePrefix "/" path;
    in
    lib.match "/[A-Za-z0-9_./-]+" path != null
    && lib.path.subpath.isValid subpath
    && subpath != "."
    && lib.path.subpath.normalise subpath == "./${subpath}";
  subvolumeType = lib.types.submodule {
    options = {
      user = lib.mkOption {
        type = lib.types.str;
        default = "root";
        description = "Owner of the source subvolume.";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "root";
        description = "Group of the source subvolume.";
      };
      mode = lib.mkOption {
        type = lib.types.strMatching "0[0-7]{3}";
        default = "0700";
        description = "Permissions of the source subvolume.";
      };
    };
  };
  groupType = lib.types.submodule (
    { name, ... }: {
      options = {
        units = lib.mkOption {
          type = lib.types.listOf (lib.types.strMatching /* regex */ "[A-Za-z0-9_.@:-]+\\.(service|timer|socket|path)");
          default = [ ];
          description = "Writer and activation units in start order. They stop in reverse order. Only previously active units are restarted.";
        };
        subvolumes = lib.mkOption {
          type = lib.types.attrsOf subvolumeType;
          description = "Absolute source subvolume paths and their ownership. Existing directories require manual conversion.";
        };
        databases = lib.mkOption {
          type = lib.types.listOf (lib.types.strMatching /* regex */ "[A-Za-z0-9_][A-Za-z0-9_.-]*");
          default = [ ];
          description = "Local PostgreSQL databases to dump after stopping the writers.";
        };
        recoveryFiles = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          description = "Named recovery files copied into the snapshot. Prefer encrypted agenix master files.";
        };
        stateDirectory = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/service-snapshots/${name}";
          description = "Dedicated Btrfs subvolume for database dumps and recovery files.";
        };
        onCalendar = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "*-*-* 04:00:00";
          description = "Snapshot schedule. Null disables the timer.";
        };
        retention = lib.mkOption {
          type = lib.types.str;
          default = "14d";
          description = "btrbk snapshot retention policy. The latest snapshot is always kept.";
        };
      };
    }
  );
  prepare = name: group: /* bash */ ''
    set -euo pipefail
    ${snapshotConfiguration name group}
    umask 077
    : > "$RUNTIME_DIRECTORY/active-units"
    declare -A declared_subvolumes=() declared_paths=()
    for source in ${lib.escapeShellArgs (sourcePaths group)}; do
      [[ ! -L "$source" ]]
      if ! btrfs subvolume show "$source" >/dev/null; then
        printf 'Prepare %s as a Btrfs subvolume before capturing %s.\n' "$source" "''${snapshot_names["$source"]}" >&2
        exit 1
      fi
      uuid=$(findmnt --noheadings --output UUID --target "$source")
      [[ -n "$uuid" ]]
      [[ "$uuid" == "$(findmnt --noheadings --output UUID --target "''${snapshot_directories["$source"]}")" ]]
      declared_paths["$source"]=1
      id=$(btrfs inspect-internal rootid "$source")
      declared_subvolumes["$uuid:$id"]=1
    done
    mounts=$(findmnt --raw --noheadings --output TARGET)
    for source in ${lib.escapeShellArgs (sourcePaths group)}; do
      while IFS= read -r mount; do
        if [[ "$mount" == "$source/"* && -z "''${declared_paths["$mount"]:-}" ]]; then
          printf 'Undeclared nested mount below %s; no services stopped.\n' "$source" >&2
          exit 1
        fi
      done <<< "$mounts"
      uuid=$(findmnt --noheadings --output UUID --target "$source")
      nested_ids=$(btrfs subvolume list -o "$source" | awk '$1 == "ID" { print $2 }')
      while IFS= read -r id; do
        [[ -n "$id" ]] || continue
        if [[ -z "''${declared_subvolumes["$uuid:$id"]:-}" ]]; then
          printf 'Undeclared nested subvolume below %s; no services stopped.\n' "$source" >&2
          exit 1
        fi
      done <<< "$nested_ids"
    done
    for unit in ${lib.escapeShellArgs group.units}; do
      [[ "$(systemctl show --property=LoadState --value "$unit")" == loaded ]]
      state=$(systemctl show --property=ActiveState --value "$unit")
      case "$state" in
        active|inactive|failed) ;;
        *) printf 'Service %s is %s; try again after it settles.\n' "$unit" "$state" >&2; exit 1 ;;
      esac
    done
    for unit in ${lib.escapeShellArgs group.units}; do
      if systemctl is-active --quiet "$unit"; then
        printf '%s\n' "$unit" >> "$RUNTIME_DIRECTORY/active-units"
      fi
    done
    ${lib.pipe group.units [
      lib.reverseList
      (lib.map (unit: /* bash */ "systemctl stop ${lib.escapeShellArg unit}"))
      (lib.concatStringsSep "\n")
    ]}
    ${lib.concatMapStringsSep "\n" (database: /* bash */ ''
      runuser -u postgres -- pg_dump --format=custom --host=${lib.escapeShellArg socketDirectories} --username=postgres --port=${builtins.toString config.services.postgresql.settings.port} --dbname=${lib.escapeShellArg database} \
        > ${lib.escapeShellArg "${group.stateDirectory}/${database}.dump.tmp"}
      pg_restore --list ${lib.escapeShellArg "${group.stateDirectory}/${database}.dump.tmp"} >/dev/null
      mv -- ${lib.escapeShellArg "${group.stateDirectory}/${database}.dump.tmp"} ${lib.escapeShellArg "${group.stateDirectory}/${database}.dump"}
    '') group.databases}
    ${lib.pipe group.recoveryFiles [
      (lib.mapAttrsToList (
        fileName: file: /* bash */ ''
          cp --dereference -- ${lib.escapeShellArg (builtins.toString file)} ${lib.escapeShellArg "${group.stateDirectory}/recovery-${fileName}"}
        ''
      ))
      (lib.concatStringsSep "\n")
    ]}
    readlink -f /run/current-system > ${lib.escapeShellArg "${group.stateDirectory}/system-path"}
    date --utc --iso-8601=ns > ${lib.escapeShellArg "${group.stateDirectory}/checkpoint-time"}
  '';
  complete = name: group: /* bash */ ''
    set -euo pipefail
    export LC_ALL=C
    ${snapshotConfiguration name group}
    expected_suffix=
    state_snapshot=
    : > "$RUNTIME_DIRECTORY/complete-manifest"
    for source in ${lib.escapeShellArgs (sourcePaths group)}; do
      prefix="''${snapshot_directories["$source"]}/''${snapshot_names["$source"]}."
      latest=
      for snapshot in "$prefix"*; do
        if [[ -d "$snapshot" ]]; then latest="$snapshot"; fi
      done
      [[ -n "$latest" ]]
      suffix="''${latest#"$prefix"}"
      if [[ -n "$expected_suffix" && "$suffix" != "$expected_suffix" ]]; then
        printf 'Incomplete consistency group: snapshot timestamps differ.\n' >&2
        exit 1
      fi
      expected_suffix="$suffix"
      printf '%s\t%s\n' "$source" "$latest" >> "$RUNTIME_DIRECTORY/complete-manifest"
      if [[ "$source" == ${lib.escapeShellArg group.stateDirectory} ]]; then state_snapshot="$latest"; fi
    done
    cmp --silent ${lib.escapeShellArg "${group.stateDirectory}/checkpoint-time"} "$state_snapshot/checkpoint-time"
    cp -- "$RUNTIME_DIRECTORY/complete-manifest" "$state_snapshot.complete.tmp"
    mv -- "$state_snapshot.complete.tmp" "$state_snapshot.complete"
    printf 'Complete service snapshot: %s\n' "$state_snapshot.complete"
  '';
  resume = name: group: /* bash */ ''
    set -uo pipefail
    status=0
    ${lib.optionalString (group.databases != [ ]) /* bash */ ''
      rm -f -- ${
        lib.pipe group.databases [
          (lib.map (database: "${group.stateDirectory}/${database}.dump.tmp"))
          lib.escapeShellArgs
        ]
      } || status=1
    ''}
    if [[ -f "$RUNTIME_DIRECTORY/active-units" ]]; then
      while IFS= read -r unit; do
        systemctl start "$unit" || status=1
      done < "$RUNTIME_DIRECTORY/active-units"
    fi
    if [[ "$status" == 0 && "''${SERVICE_RESULT:-}" == success ]]; then
      ${pkgs.btrbk}/bin/btrbk -c /etc/btrbk/${instanceName name}.conf prune || status=$?
      for marker in ${lib.escapeShellArg "${snapshotDirectory group group.stateDirectory}/${snapshotName name group.stateDirectory}."}*.complete; do
        [[ -e "$marker" ]] || continue
        [[ -d "''${marker%.complete}" ]] || rm -- "$marker" || status=1
      done
    fi
    exit "$status"
  '';
in
{
  options.rix101.serviceSnapshots.groups = lib.mkOption {
    type = lib.types.attrsOf groupType;
    default = { };
    description = "Consistency groups for application-aware, local Btrfs snapshots managed by btrbk.";
  };

  config = lib.mkIf (groups != { }) {
    assertions = [
      {
        assertion = lib.length allUnits == lib.length (lib.unique allUnits);
        message = "A unit can belong to only one serviceSnapshots group.";
      }
      {
        assertion = lib.length allSources == lib.length (lib.unique allSources);
        message = "A subvolume can belong to only one serviceSnapshots group.";
      }
      {
        assertion = lib.all validPath allSources;
        message = "serviceSnapshots source paths must be normalized absolute paths without spaces.";
      }
      {
        assertion = lib.pipe groups [
          lib.attrValues
          (lib.all (
            group: group.databases == [ ] || (config.services.postgresql.enable && socketDirectories != "")
          ))
        ];
        message = "serviceSnapshots databases require local PostgreSQL with Unix sockets.";
      }
      {
        assertion = lib.pipe groups [
          lib.attrValues
          (lib.all (group: group.databases == [ ] || !(lib.elem "postgresql.service" group.units)))
        ];
        message = "serviceSnapshots must not stop PostgreSQL when dumping its databases.";
      }
      {
        assertion = lib.pipe groups [
          lib.attrValues
          (lib.all (
            group:
            lib.pipe group.subvolumes [
              lib.attrNames
              (lib.any (path: lib.hasPrefix "${path}/" group.stateDirectory))
              (nested: !nested)
            ]
          ))
        ];
        message = "serviceSnapshots recovery state must be outside application subvolumes.";
      }
    ]
    ++ lib.mapAttrsToList (name: group: {
      assertion =
        lib.match "[a-z0-9][a-z0-9-]*" name != null
        && lib.pipe group.recoveryFiles [
          lib.attrNames
          (lib.all (fileName: lib.match "[A-Za-z0-9_][A-Za-z0-9_.-]*" fileName != null))
        ];
      message = "serviceSnapshots group and recovery-file names must be safe file names.";
    }) groups;

    services.btrbk.instances = lib.mapAttrs' (
      name: group:
      lib.nameValuePair (instanceName name) {
        inherit (group) onCalendar;
        snapshotOnly = true;
        settings = {
          backend = "btrfs-progs";
          timestamp_format = "long-iso";
          snapshot_create = "always";
          lockfile = "/run/${instanceName name}/btrbk.lock";
          snapshot_preserve_min = "latest";
          snapshot_preserve = group.retention;
          subvolume = lib.genAttrs (sourcePaths group) (path: {
            snapshot_dir = snapshotDirectory group path;
            snapshot_name = snapshotName name path;
          });
        };
      }
    ) groups;

    systemd.tmpfiles.rules = lib.pipe groups [
      lib.attrValues
      (lib.concatMap (
        group:
        (lib.mapAttrsToList (
          path: ownership: "v ${path} ${ownership.mode} ${ownership.user} ${ownership.group} -"
        ) group.subvolumes)
        ++ [ ("v ${group.stateDirectory} 0700 root root -") ]
        ++ lib.pipe (sourcePaths group) [
          (lib.map (snapshotDirectory group))
          lib.unique
          (lib.map (path: "d ${path} 0700 root root -"))
        ]
      ))
    ];

    systemd.services = lib.mapAttrs' (
      name: group:
      lib.nameValuePair "btrbk-${instanceName name}" {
        unitConfig.RequiresMountsFor = sourcePaths group;
        path = [
          pkgs.btrfs-progs
          pkgs.coreutils
          pkgs.diffutils
          pkgs.gawk
          pkgs.util-linux
          pkgs.systemd
        ]
        ++ lib.optional (group.databases != [ ]) config.services.postgresql.package;
        after = lib.optional (group.databases != [ ]) "postgresql.service";
        requires = lib.optional (group.databases != [ ]) "postgresql.service";
        environment.TZ = "UTC";
        preStart = prepare name group;
        postStart = complete name group;
        postStop = resume name group;
        serviceConfig = {
          ExecStart =
            lib.mkForce
              /* bash */ "${pkgs.btrbk}/bin/btrbk --preserve -c /etc/btrbk/${instanceName name}.conf snapshot";
          User = lib.mkForce "root";
          Group = lib.mkForce "root";
          RuntimeDirectory = instanceName name;
          RuntimeDirectoryMode = "0700";
          UMask = "0077";
          TimeoutStartSec = "30min";
          TimeoutStopSec = "30min";
        };
      }
    ) groups;
  };
}
