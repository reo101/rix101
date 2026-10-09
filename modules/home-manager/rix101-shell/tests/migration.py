"""Tests for migrate-state.py. Runs entirely inside a temporary directory."""

from __future__ import annotations

import importlib.util
import io
import os
import sqlite3
import stat
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch

SCRIPT_PATH = Path(__file__).resolve().parent.parent / "migrate-state.py"
MODULE_SPEC = importlib.util.spec_from_file_location(
    "shell_state_migration", SCRIPT_PATH
)
MIGRATION_MODULE = importlib.util.module_from_spec(MODULE_SPEC)
MODULE_SPEC.loader.exec_module(MIGRATION_MODULE)


def run_migration(*arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT_PATH), *arguments],
        capture_output=True,
        text=True,
        check=False,
    )


class MigrationCommandTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory(
            prefix="migrate-state-test-"
        )
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = Path(self.temporary_directory.name)
        self.atuin_source = self.root / "old-atuin"
        self.atuin_destination = self.root / "new-atuin"
        self.history_source = self.root / "old-history"
        self.history_destination = self.root / "nested" / "new-history"
        self.atuin_source.mkdir()
        self.history_destination.parent.mkdir()
        self.history_source.write_text("command-a\n")

    def seed_atuin_source(self) -> sqlite3.Connection:
        """Create an Atuin source whose database lives in a persistent WAL."""
        database_path = self.atuin_source / "history.db"
        connection = sqlite3.connect(database_path)
        connection.execute("PRAGMA journal_mode=WAL")
        connection.execute(
            "CREATE TABLE history (id INTEGER PRIMARY KEY, command TEXT NOT NULL)"
        )
        connection.executemany(
            "INSERT INTO history (command) VALUES (?)",
            [(f"command-{index}",) for index in range(3)],
        )
        connection.commit()
        self.addCleanup(connection.close)
        return connection

    def test_wal_snapshot_is_consistent(self) -> None:
        self.seed_atuin_source()
        self.assertTrue(
            (self.atuin_source / "history.db-wal").is_file(),
            "fixture failed to produce a WAL file; test is not exercising WAL snapshotting",
        )
        result = run_migration(
            "--atuin-source",
            str(self.atuin_source),
            "--atuin-destination",
            str(self.atuin_destination),
            "--confirm-quiescent",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        migrated = sqlite3.connect(self.atuin_destination / "history.db")
        try:
            rows = migrated.execute(
                "SELECT command FROM history ORDER BY id"
            ).fetchall()
        finally:
            migrated.close()
        self.assertEqual(rows, [(f"command-{index}",) for index in range(3)])
        self.assertFalse((self.atuin_destination / "history.db-wal").exists())
        self.assertFalse((self.atuin_destination / "history.db-shm").exists())
        self.assertFalse((self.atuin_destination / "history.db-journal").exists())

    def test_key_file_copied_and_destination_private(self) -> None:
        (self.atuin_source / "key").write_text("secret-key")
        self.seed_atuin_source()
        result = run_migration(
            "--atuin-source",
            str(self.atuin_source),
            "--atuin-destination",
            str(self.atuin_destination),
            "--confirm-quiescent",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.atuin_destination / "key").is_file())
        self.assertEqual(
            (self.atuin_destination / "key").read_text(),
            "secret-key",
            "non-database state was not preserved",
        )
        destination_mode = stat.S_IMODE(self.atuin_destination.stat().st_mode)
        self.assertEqual(destination_mode, 0o700)

    def test_refuses_populated_destination(self) -> None:
        self.seed_atuin_source()
        self.atuin_destination.mkdir()
        stray = self.atuin_destination / "leftover"
        stray.write_text("stray")
        result = run_migration(
            "--atuin-source",
            str(self.atuin_source),
            "--atuin-destination",
            str(self.atuin_destination),
            "--confirm-quiescent",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("populated", result.stderr)
        self.assertTrue(stray.exists())

    def test_refuses_partial_destination(self) -> None:
        self.seed_atuin_source()
        self.atuin_destination.mkdir()
        (self.atuin_destination / "key").write_text("already present")
        result = run_migration(
            "--atuin-source",
            str(self.atuin_source),
            "--atuin-destination",
            str(self.atuin_destination),
            "--confirm-quiescent",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.atuin_destination / "history.db").exists())

    def test_refuses_destination_broken_symlink(self) -> None:
        self.seed_atuin_source()
        os.symlink(self.root / "does-not-exist", self.atuin_destination)
        result = run_migration(
            "--atuin-source",
            str(self.atuin_source),
            "--atuin-destination",
            str(self.atuin_destination),
            "--confirm-quiescent",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(os.path.islink(self.atuin_destination))

    def test_refuses_history_destination_broken_symlink(self) -> None:
        os.symlink(self.root / "does-not-exist", self.history_destination)
        result = run_migration(
            "--history-source",
            str(self.history_source),
            "--history-destination",
            str(self.history_destination),
            "--confirm-quiescent",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(os.path.islink(self.history_destination))

    def test_dry_run_writes_nothing(self) -> None:
        self.seed_atuin_source()
        result = run_migration(
            "--atuin-source",
            str(self.atuin_source),
            "--atuin-destination",
            str(self.atuin_destination),
            "--history-source",
            str(self.history_source),
            "--history-destination",
            str(self.history_destination),
            "--dry-run",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("preflight passed", result.stdout)
        self.assertFalse(self.atuin_destination.exists())
        self.assertFalse(self.history_destination.exists())
        self.assertFalse(
            [path for path in self.root.iterdir() if ".migration-" in path.name],
            "dry run left staging entries behind",
        )

    def test_sources_remain_intact_after_migration(self) -> None:
        connection = self.seed_atuin_source()
        result = run_migration(
            "--atuin-source",
            str(self.atuin_source),
            "--atuin-destination",
            str(self.atuin_destination),
            "--history-source",
            str(self.history_source),
            "--history-destination",
            str(self.history_destination),
            "--confirm-quiescent",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        source_rows = connection.execute("SELECT count(*) FROM history").fetchone()[0]
        self.assertEqual(source_rows, 3)
        self.assertTrue((self.atuin_source / "history.db").is_file())
        self.assertTrue((self.atuin_source / "history.db-wal").is_file())
        connection.close()

    def test_missing_confirm_refuses_transfer(self) -> None:
        self.seed_atuin_source()
        result = run_migration(
            "--atuin-source",
            str(self.atuin_source),
            "--atuin-destination",
            str(self.atuin_destination),
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("confirm-quiescent", result.stderr)
        self.assertFalse(self.atuin_destination.exists())
        self.assertFalse(
            [path for path in self.root.iterdir() if ".migration-" in path.name],
            "refused transfer left staging entries behind",
        )

    def test_refuses_destination_inside_source(self) -> None:
        self.seed_atuin_source()
        nested_destination = self.atuin_source / "nested-atuin"
        result = run_migration(
            "--atuin-source",
            str(self.atuin_source),
            "--atuin-destination",
            str(nested_destination),
            "--confirm-quiescent",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("inside source", result.stderr)

    def test_refuses_source_inside_destination(self) -> None:
        self.seed_atuin_source()
        result = run_migration(
            "--atuin-source",
            str(self.atuin_source),
            "--atuin-destination",
            str(self.root),
            "--confirm-quiescent",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("inside destination", result.stderr)

    def test_refuses_unpaired_arguments(self) -> None:
        result = run_migration("--atuin-source", str(self.atuin_source))
        self.assertNotEqual(result.returncode, 0)

    def test_history_file_copied_without_overwrite(self) -> None:
        self.history_source.write_text("command-a\ncommand-b\n")
        os.chmod(self.history_source, 0o600)
        result = run_migration(
            "--history-source",
            str(self.history_source),
            "--history-destination",
            str(self.history_destination),
            "--confirm-quiescent",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.history_destination.read_text(), "command-a\ncommand-b\n")
        self.assertEqual(
            stat.S_IMODE(self.history_destination.stat().st_mode),
            0o600,
            "history file mode was not preserved",
        )
        self.assertTrue(
            self.history_source.exists(), "history source was not preserved"
        )

    def test_history_destination_populated_refused(self) -> None:
        self.history_source.write_text("command-a\n")
        self.history_destination.write_text("already migrated\n")
        result = run_migration(
            "--history-source",
            str(self.history_source),
            "--history-destination",
            str(self.history_destination),
            "--confirm-quiescent",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.history_destination.read_text(), "already migrated\n")

    def test_accepts_precreated_empty_directory(self) -> None:
        self.seed_atuin_source()
        self.atuin_destination.mkdir(mode=0o755)
        result = run_migration(
            "--atuin-source",
            str(self.atuin_source),
            "--atuin-destination",
            str(self.atuin_destination),
            "--confirm-quiescent",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(stat.S_IMODE(self.atuin_destination.stat().st_mode), 0o700)

    def test_refuses_database_symlink(self) -> None:
        self.seed_atuin_source()
        (self.atuin_source / "records.db").symlink_to("history.db")
        result = run_migration(
            "--atuin-source",
            str(self.atuin_source),
            "--atuin-destination",
            str(self.atuin_destination),
            "--confirm-quiescent",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("symlink", result.stderr)
        self.assertFalse(self.atuin_destination.exists())

    def test_refuses_cross_component_source_overlap(self) -> None:
        self.seed_atuin_source()
        result = run_migration(
            "--atuin-source",
            str(self.atuin_source),
            "--atuin-destination",
            str(self.atuin_destination),
            "--history-source",
            str(self.history_source),
            "--history-destination",
            str(self.atuin_source / "new-history"),
            "--confirm-quiescent",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.atuin_source / "new-history").exists())
        self.assertFalse(self.atuin_destination.exists())

    def test_invalid_database_cleans_staging_before_publication(self) -> None:
        self.seed_atuin_source()
        (self.atuin_source / "invalid.db").write_text("not SQLite")
        result = run_migration(
            "--atuin-source",
            str(self.atuin_source),
            "--atuin-destination",
            str(self.atuin_destination),
            "--history-source",
            str(self.history_source),
            "--history-destination",
            str(self.history_destination),
            "--confirm-quiescent",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.atuin_destination.exists())
        self.assertFalse(self.history_destination.exists())
        self.assertFalse(list(self.root.glob(".*.migration-*")))

    def test_history_publication_never_overwrites_concurrent_file(self) -> None:
        original_link = os.link

        def concurrent_link(source, destination):
            destination.write_text("concurrent writer\n")
            original_link(source, destination)

        with (
            patch.object(MIGRATION_MODULE.os, "link", side_effect=concurrent_link),
            redirect_stdout(io.StringIO()),
            redirect_stderr(io.StringIO()),
        ):
            result = MIGRATION_MODULE.main(
                [
                    "--history-source",
                    str(self.history_source),
                    "--history-destination",
                    str(self.history_destination),
                    "--confirm-quiescent",
                ]
            )
        self.assertEqual(result, 1)
        self.assertEqual(self.history_destination.read_text(), "concurrent writer\n")
        self.assertFalse(list(self.history_destination.parent.glob(".*.migration-*")))

    def test_relative_database_paths(self) -> None:
        self.seed_atuin_source()
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT_PATH),
                "--atuin-source",
                self.atuin_source.name,
                "--atuin-destination",
                self.atuin_destination.name,
                "--confirm-quiescent",
            ],
            cwd=self.root,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
