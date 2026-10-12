{ pkgs, ... }:
{
  name = "service-snapshots";

  nodes.machine = { pkgs, ... }: {
    imports = [ ../default.nix ];
    environment.systemPackages = [
      pkgs.btrfs-progs
      pkgs.diffutils
      pkgs.util-linux
    ];
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "snapshots" ];
    };
    systemd.services.btrbk-service-snapshots-fixture.startLimitIntervalSec = 0;
    systemd.services.snapshot-writer = {
      startLimitIntervalSec = 0;
      serviceConfig.ExecStart = /* bash */ "${pkgs.coreutils}/bin/sleep infinity";
      serviceConfig.ExecStop = "${pkgs.writeShellScript "snapshot-writer-stop" (
        /* bash */ "echo writer >> /run/snapshot-stop-order"
      )}";
    };
    systemd.services.snapshot-client = {
      startLimitIntervalSec = 0;
      serviceConfig.ExecStart = /* bash */ "${pkgs.coreutils}/bin/sleep infinity";
      serviceConfig.ExecStop = "${pkgs.writeShellScript "snapshot-client-stop" (
        /* bash */ "echo client >> /run/snapshot-stop-order"
      )}";
    };
    systemd.timers.snapshot-idle.timerConfig.OnActiveSec = "1h";
    systemd.services.snapshot-idle = {
      serviceConfig.ExecStart = /* bash */ "${pkgs.coreutils}/bin/sleep infinity";
    };
    rix101.serviceSnapshots.groups.fixture = {
      units = [
        "snapshot-writer.service"
        "snapshot-client.service"
        "snapshot-idle.service"
        "snapshot-idle.timer"
      ];
      subvolumes = {
        "/mnt/state/app" = { };
        "/mnt/state/app/nested" = { };
        "/mnt/blobs/data" = { };
      };
      stateDirectory = "/mnt/state/recovery";
      databases = [ "snapshots" ];
      recoveryFiles."fixture.age" = pkgs.writeText "fixture.age" "encrypted-key-fixture\n";
      onCalendar = null;
    };
  };

  testScript = /* python */ ''
    machine.start()
    machine.wait_for_unit("postgresql.service")
    for name in ("state", "blobs"):
        machine.succeed(f"truncate -s 256M /{name}-filesystem; mkfs.btrfs /{name}-filesystem")
        machine.succeed(f"mkdir -p /mnt/{name}; mount /{name}-filesystem /mnt/{name}")
    for source in ("/mnt/state/app", "/mnt/state/app/nested", "/mnt/state/recovery", "/mnt/blobs/data"):
        machine.succeed(f"btrfs subvolume create {source}")
    machine.succeed("systemd-tmpfiles --create")
    machine.succeed("echo original > /mnt/state/app/record; echo nested > /mnt/state/app/nested/record; echo blob > /mnt/blobs/data/blob")
    machine.succeed("runuser -u postgres -- psql snapshots -c \"CREATE TABLE records (value text); INSERT INTO records VALUES ('original');\"")
    machine.succeed("systemctl start snapshot-writer.service snapshot-client.service snapshot-idle.timer")

    with subtest("consistent read-only snapshots and database restoration"):
        machine.succeed("systemctl start btrbk-service-snapshots-fixture.service")
        machine.succeed("systemctl is-active snapshot-writer.service snapshot-client.service snapshot-idle.timer")
        machine.succeed("printf 'client\\nwriter\\n' | cmp - /run/snapshot-stop-order")
        machine.fail("systemctl is-active --quiet snapshot-idle.service")
        machine.succeed("set -- /mnt/state/.service-snapshots/fixture-app-*; test $(btrfs property get -ts \"$1\" ro) = ro=true")
        machine.succeed("echo changed > /mnt/state/app/record")
        machine.succeed("set -- /mnt/state/.service-snapshots/fixture-app-*; grep -qx original \"$1/record\"")
        machine.succeed("set -- /mnt/state/.service-snapshots/fixture-nested-*; grep -qx nested \"$1/record\"")
        machine.succeed("set -- /mnt/blobs/.service-snapshots/fixture-data-*; grep -qx blob \"$1/blob\"")
        machine.succeed("set -- /mnt/state/.service-snapshots/fixture-recovery-*; grep -qx encrypted-key-fixture \"$1/recovery-fixture.age\"")
        machine.succeed("set -- /mnt/state/.service-snapshots/fixture-recovery-*.complete; test $(wc -l < \"$1\") = 4")
        machine.succeed("runuser -u postgres -- createdb snapshots_restored")
        machine.succeed("set -- /mnt/state/.service-snapshots/fixture-recovery-*; runuser -u postgres -- pg_restore --dbname=snapshots_restored < \"$1/snapshots.dump\"")
        machine.succeed("runuser -u postgres -- psql --tuples-only --no-align snapshots_restored -c 'SELECT value FROM records' | grep -qx original")

    with subtest("undeclared nested subvolumes fail before stopping writers"):
        machine.succeed("btrfs subvolume create /mnt/state/app/undeclared")
        machine.fail("systemctl start btrbk-service-snapshots-fixture.service")
        machine.succeed("systemctl is-active snapshot-writer.service")
        machine.fail("systemctl is-active --quiet snapshot-idle.service")
        machine.succeed("btrfs subvolume delete /mnt/state/app/undeclared")
        machine.succeed("systemctl reset-failed btrbk-service-snapshots-fixture.service")

    with subtest("undeclared nested mounts fail before stopping writers"):
        machine.succeed("mkdir /mnt/state/app/foreign; mount -t tmpfs tmpfs /mnt/state/app/foreign")
        machine.fail("systemctl start btrbk-service-snapshots-fixture.service")
        machine.succeed("systemctl is-active snapshot-writer.service")
        machine.succeed("umount /mnt/state/app/foreign")
        machine.succeed("systemctl reset-failed btrbk-service-snapshots-fixture.service")

    machine.succeed("set -- /mnt/state/.service-snapshots/fixture-app-*; btrfs subvolume snapshot -r /mnt/state/app \"''${1%.*}.20000101T000000+0000\"")
    with subtest("snapshot command failure restarts only previously active services"):
        machine.succeed("mkdir -p /run/systemd/system/btrbk-service-snapshots-fixture.service.d")
        machine.succeed("printf '%s\\n' '[Service]' 'ExecStart=' 'ExecStart=${pkgs.coreutils}/bin/false' > /run/systemd/system/btrbk-service-snapshots-fixture.service.d/failure.conf")
        machine.succeed("systemctl daemon-reload")
        machine.fail("systemctl start btrbk-service-snapshots-fixture.service")
        machine.succeed("systemctl is-active snapshot-writer.service")
        machine.fail("systemctl is-active --quiet snapshot-idle.service")
        machine.succeed("rm /run/systemd/system/btrbk-service-snapshots-fixture.service.d/failure.conf; systemctl daemon-reload")
        machine.succeed("systemctl reset-failed btrbk-service-snapshots-fixture.service")
        machine.succeed("test -d /mnt/state/.service-snapshots/fixture-app-*.20000101T000000+0000")

    with subtest("dump failure restarts only previously active services"):
        machine.succeed("runuser -u postgres -- dropdb snapshots")
        machine.fail("systemctl start btrbk-service-snapshots-fixture.service")
        machine.succeed("systemctl is-active snapshot-writer.service")
        machine.fail("systemctl is-active --quiet snapshot-idle.service")
        machine.fail("test -e /mnt/state/recovery/snapshots.dump.tmp")
        machine.succeed("set -- /mnt/state/.service-snapshots/fixture-recovery-*; for snapshot in \"$@\"; do test -d \"$snapshot\" || continue; pg_restore --list \"$snapshot/snapshots.dump\" >/dev/null; done")

    with subtest("retention runs only after a completed checkpoint"):
        machine.succeed("test -d /mnt/state/.service-snapshots/fixture-app-*.20000101T000000+0000")
        machine.succeed("runuser -u postgres -- createdb snapshots")
        machine.succeed("systemctl reset-failed btrbk-service-snapshots-fixture.service")
        machine.sleep(1)
        machine.succeed("systemctl start btrbk-service-snapshots-fixture.service")
        machine.fail("test -d /mnt/state/.service-snapshots/fixture-app-*.20000101T000000+0000")
        machine.succeed("systemctl is-active snapshot-writer.service")

    with subtest("atomic directory conversion preserves the original"):
        machine.succeed("mkdir /mnt/state/conversion; echo original > /mnt/state/conversion/record")
        machine.succeed("btrfs subvolume create /mnt/state/conversion-new")
        machine.succeed("cp --archive --reflink=always /mnt/state/conversion/. /mnt/state/conversion-new/")
        machine.succeed("diff --recursive --brief /mnt/state/conversion /mnt/state/conversion-new")
        machine.succeed("mv --exchange --no-copy --no-target-directory /mnt/state/conversion /mnt/state/conversion-new")
        machine.succeed("btrfs subvolume show /mnt/state/conversion; grep -qx original /mnt/state/conversion-new/record")
  '';
}
