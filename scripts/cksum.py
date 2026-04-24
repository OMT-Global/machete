#!/usr/bin/env python3
import argparse
import hashlib
import os
import sqlite3
import sys
import time
from pathlib import Path


SCHEMA = """
CREATE TABLE IF NOT EXISTS checksums (
  scope TEXT NOT NULL,
  path TEXT NOT NULL,
  sha256 TEXT NOT NULL,
  size INTEGER NOT NULL,
  mtime_ns INTEGER NOT NULL,
  last_hashed REAL NOT NULL,
  PRIMARY KEY (scope, path)
);
"""

EXCLUDED_DIR_NAMES = {
    ".Trash",
    ".cache",
    ".git",
    ".machete",
    "Library/Caches",
    "node_modules",
}


def connect(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute(SCHEMA)
    return conn


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def stat_record(path: Path) -> tuple[int, int]:
    stat = path.stat()
    return stat.st_size, stat.st_mtime_ns


def load_existing(conn: sqlite3.Connection, scope: str) -> dict[str, dict[str, object]]:
    rows = conn.execute(
        "SELECT path, sha256, size, mtime_ns FROM checksums WHERE scope = ?",
        (scope,),
    ).fetchall()
    return {
        row[0]: {"sha256": row[1], "size": row[2], "mtime_ns": row[3]}
        for row in rows
    }


def checksum_for(path: Path, existing: dict[str, object] | None) -> tuple[str, int, int]:
    size, mtime_ns = stat_record(path)
    if existing and existing["size"] == size and existing["mtime_ns"] == mtime_ns:
        return str(existing["sha256"]), size, mtime_ns
    return sha256_file(path), size, mtime_ns


def upsert(conn: sqlite3.Connection, scope: str, path: str, sha256: str, size: int, mtime_ns: int) -> None:
    conn.execute(
        """
        INSERT INTO checksums(scope, path, sha256, size, mtime_ns, last_hashed)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(scope, path) DO UPDATE SET
          sha256 = excluded.sha256,
          size = excluded.size,
          mtime_ns = excluded.mtime_ns,
          last_hashed = excluded.last_hashed
        """,
        (scope, path, sha256, size, mtime_ns, time.time()),
    )


def read_tracked_paths(path_file: Path) -> list[Path]:
    raw = path_file.read_bytes()
    return [Path(os.fsdecode(item)) for item in raw.split(b"\0") if item]


def should_skip_home_path(home: Path, path: Path) -> bool:
    try:
        rel = path.relative_to(home)
    except ValueError:
        return False

    parts = rel.parts
    if not parts:
        return False
    if parts[0] in EXCLUDED_DIR_NAMES:
        return True
    if len(parts) >= 2 and "/".join(parts[:2]) in EXCLUDED_DIR_NAMES:
        return True
    return any(part in EXCLUDED_DIR_NAMES for part in parts)


def walk_home(home: Path) -> list[Path]:
    paths = []
    for root, dirs, files in os.walk(home):
        root_path = Path(root)
        dirs[:] = [
            directory
            for directory in dirs
            if not should_skip_home_path(home, root_path / directory)
        ]
        for filename in files:
            path = root_path / filename
            if not should_skip_home_path(home, path) and path.is_file():
                paths.append(path)
    return sorted(paths)


def compare(
    conn: sqlite3.Connection,
    scope: str,
    paths: list[Path],
    report_missing_baseline_paths: bool,
) -> int:
    existing = load_existing(conn, scope)
    current = {str(path): path for path in paths}
    statuses: list[tuple[str, str]] = []
    updated_metadata = False

    for path_string, path in sorted(current.items()):
        if not path.exists():
            statuses.append(("MISSING", path_string))
            continue
        if not path.is_file():
            continue

        previous = existing.get(path_string)
        sha256, size, mtime_ns = checksum_for(path, previous)
        if previous is None:
            statuses.append(("NEW", path_string))
        elif previous["sha256"] != sha256:
            statuses.append(("CHANGED", path_string))
        elif previous["size"] != size or previous["mtime_ns"] != mtime_ns:
            upsert(conn, scope, path_string, sha256, size, mtime_ns)
            updated_metadata = True

    if report_missing_baseline_paths:
        for path_string in sorted(set(existing) - set(current)):
            statuses.append(("MISSING", path_string))

    if updated_metadata:
        conn.commit()

    if not statuses:
        print("OK no checksum drift found")
        return 0

    for status, path_string in statuses:
        print(f"{status} {path_string}")
    return 1


def init_baseline(conn: sqlite3.Connection, scope: str, paths: list[Path]) -> int:
    existing = load_existing(conn, scope)
    count = 0
    for path in paths:
        if not path.exists() or not path.is_file():
            continue
        path_string = str(path)
        sha256, size, mtime_ns = checksum_for(path, existing.get(path_string))
        upsert(conn, scope, path_string, sha256, size, mtime_ns)
        count += 1

    conn.commit()
    print(f"Baseline updated for {count} file(s)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="SQLite-backed SHA256 checksums for machete")
    parser.add_argument("--db", required=True)
    parser.add_argument("--scope", required=True)
    parser.add_argument("--mode", choices=("init", "verify", "check"), required=True)
    parser.add_argument("--paths-file")
    parser.add_argument("--home")
    args = parser.parse_args()

    if args.paths_file:
        paths = read_tracked_paths(Path(args.paths_file))
    elif args.home:
        paths = walk_home(Path(args.home))
    else:
        parser.error("one of --paths-file or --home is required")

    conn = connect(Path(args.db))
    try:
        if args.mode == "init":
            return init_baseline(conn, args.scope, paths)
        return compare(
            conn,
            scope=args.scope,
            paths=paths,
            report_missing_baseline_paths=args.mode == "verify",
        )
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())
