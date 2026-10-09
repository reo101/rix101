"""Stage shell-state snapshots, preserve sources, and refuse populated destinations.

Stop writers before --confirm-quiescent. SQLite backup is consistent per database,
not a transaction across databases. Components publish separately; sources remain
available if publishing a later component fails. --dry-run only validates paths.
"""

import argparse
import os
import shutil
import sqlite3
import sys
import tempfile
from contextlib import ExitStack, closing
from pathlib import Path

DATABASE_SUFFIXES = (".db", ".db-wal", ".db-shm", ".db-journal")


def ensure_no_overlap(source, destination):
    source_real = source.resolve()
    destination_real = destination.resolve()
    if source_real == destination_real:
        raise ValueError(f"source and destination are the same path: {source}")
    if source_real in destination_real.parents:
        raise ValueError(f"destination {destination} is inside source {source}")
    if destination_real in source_real.parents:
        raise ValueError(f"source {source} is inside destination {destination}")


def ensure_destination_available(destination, directory):
    if not os.path.lexists(destination):
        return
    if directory and not destination.is_symlink() and destination.is_dir():
        if not any(destination.iterdir()):
            return
        raise ValueError(
            f"destination is populated or partially populated: {destination}"
        )
    raise ValueError(f"destination already exists: {destination}")


def snapshot_database(source, destination):
    with (
        closing(sqlite3.connect(f"{source.as_uri()}?mode=ro", uri=True)) as original,
        closing(sqlite3.connect(destination)) as snapshot,
    ):
        original.backup(snapshot)


def stage_atuin(source, destination):
    def ignore_databases(directory, names):
        return [name for name in names if name.endswith(DATABASE_SUFFIXES)]

    destination.mkdir(mode=0o700)
    for entry in source.iterdir():
        target = destination / entry.name
        if entry.name.endswith(DATABASE_SUFFIXES):
            continue
        if entry.is_symlink():
            target.symlink_to(os.readlink(entry))
        elif entry.is_dir():
            shutil.copytree(entry, target, symlinks=True, ignore=ignore_databases)
        else:
            shutil.copy2(entry, target)
    for database in source.rglob("*.db"):
        snapshot_database(database, destination / database.relative_to(source))


def parse_arguments(argv):
    parser = argparse.ArgumentParser(
        prog="migrate-shell-state", description=__doc__, allow_abbrev=False
    )
    for component in ("atuin", "history"):
        parser.add_argument(f"--{component}-source", type=Path)
        parser.add_argument(f"--{component}-destination", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--confirm-quiescent",
        action="store_true",
        help="confirm that old shells and other writers have stopped",
    )
    arguments = parser.parse_args(argv)
    plan = []
    for component in ("atuin", "history"):
        source = getattr(arguments, f"{component}_source")
        destination = getattr(arguments, f"{component}_destination")
        if (source is None) != (destination is None):
            parser.error(
                f"--{component}-source and --{component}-destination must be given together"
            )
        if source is not None:
            plan.append((component, source.absolute(), destination.absolute()))
    if not plan:
        parser.error("nothing to migrate: pass a source/destination pair")
    if not arguments.dry_run and not arguments.confirm_quiescent:
        parser.error(
            "--confirm-quiescent is required; stop old shells and other writers first"
        )
    return arguments, plan


def main(argv):
    arguments, plan = parse_arguments(argv)
    try:
        # Validate every source and destination before creating any directories.
        for component, source, destination in plan:
            directory = component == "atuin"
            valid_source = source.is_dir() if directory else source.is_file()
            if not valid_source:
                raise ValueError(
                    f"{component} source has the wrong type or is missing: {source}"
                )
            for _, other_source, _ in plan:
                ensure_no_overlap(other_source, destination)
            ensure_destination_available(destination, directory)
            if directory:
                for database in source.rglob("*.db"):
                    if database.is_symlink() or not database.is_file():
                        raise ValueError(
                            f"database must be a regular file, not a symlink: {database}"
                        )
        if len(plan) == 2:
            ensure_no_overlap(plan[0][2], plan[1][2])
        for component, source, destination in plan:
            print(f"{component}: {source} -> {destination}")
        if arguments.dry_run:
            print("dry run: preflight passed; nothing written")
            return 0

        with ExitStack() as cleanup:
            staged = []
            for component, source, destination in plan:
                destination.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
                directory = cleanup.enter_context(
                    tempfile.TemporaryDirectory(
                        prefix=f".{destination.name}.migration-",
                        dir=destination.parent,
                    )
                )
                staging = Path(directory) / "state"
                if component == "atuin":
                    stage_atuin(source, staging)
                else:
                    shutil.copy2(source, staging)
                    staging.chmod(0o600)
                staged.append((component, staging, destination))
            for component, staging, destination in staged:
                if component == "atuin":
                    ensure_destination_available(destination, True)
                    os.rename(staging, destination)
                else:
                    # Atomic no-overwrite publication, even if a file appears after preflight.
                    os.link(staging, destination)
                    staging.unlink()
                print(f"{component}: migrated")
        return 0
    except (OSError, ValueError, sqlite3.Error) as error:
        print(f"migrate-shell-state: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
