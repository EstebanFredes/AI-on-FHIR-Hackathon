"""Step 2 — the application's metadata extractor (deterministic plumbing).

Reads a SQLite database's catalog (read-only) and emits ``source_metadata.json``
exactly as the contract in section 3 of the spec describes: tables with columns
(SQL type, nullability, comment, value samples), declared PK/FK, and lookup
table contents.

This is the deterministic half of the split in section 1: it extracts *facts*
(types, nullability, FKs, lookup rows). It never guesses meaning — that is the
agent's job.

Comments are read from the optional `_table_meta` / `_column_meta` side tables
written by the synthetic builder (SQLite has no native column comments). For a
real source database that lacks them, comments simply come back as null.
"""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import config

# Internal bookkeeping tables that must never appear as source tables.
_INTERNAL_PREFIX = "_"
_INTERNAL_TABLES = {"sqlite_sequence", "sqlite_stat1"}


def _connect_readonly(db_path: Path) -> sqlite3.Connection:
    uri = f"file:{db_path.as_posix()}?mode=ro"
    conn = sqlite3.connect(uri, uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def _list_tables(conn: sqlite3.Connection) -> list[str]:
    rows = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
    ).fetchall()
    return [
        r["name"]
        for r in rows
        if not r["name"].startswith(_INTERNAL_PREFIX) and r["name"] not in _INTERNAL_TABLES
    ]


def _table_comment(conn: sqlite3.Connection, table: str) -> str | None:
    if not _has_table(conn, "_table_meta"):
        return None
    row = conn.execute(
        "SELECT comment FROM _table_meta WHERE table_name = ?", (table,)
    ).fetchone()
    return row["comment"] if row else None


def _column_comments(conn: sqlite3.Connection, table: str) -> dict[str, str]:
    if not _has_table(conn, "_column_meta"):
        return {}
    rows = conn.execute(
        "SELECT column_name, comment FROM _column_meta WHERE table_name = ?", (table,)
    ).fetchall()
    return {r["column_name"]: r["comment"] for r in rows}


def _has_table(conn: sqlite3.Connection, name: str) -> bool:
    row = conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name = ?", (name,)
    ).fetchone()
    return row is not None


def _primary_key(conn: sqlite3.Connection, table: str) -> list[str]:
    info = conn.execute(f'PRAGMA table_info("{table}")').fetchall()
    pk = [(r["pk"], r["name"]) for r in info if r["pk"]]
    pk.sort()  # pk column carries the position within a composite key
    return [name for _, name in pk]


def _foreign_keys(conn: sqlite3.Connection, table: str) -> list[dict]:
    rows = conn.execute(f'PRAGMA foreign_key_list("{table}")').fetchall()
    # Group by FK id to support composite keys.
    by_id: dict[int, dict] = {}
    for r in rows:
        entry = by_id.setdefault(
            r["id"], {"columns": [], "ref_table": r["table"], "ref_columns": []}
        )
        entry["columns"].append(r["from"])
        entry["ref_columns"].append(r["to"])
    return [by_id[k] for k in sorted(by_id)]


def _column_samples(conn: sqlite3.Connection, table: str, column: str, limit: int) -> list:
    rows = conn.execute(
        f'SELECT DISTINCT "{column}" AS v FROM "{table}" '
        f'WHERE "{column}" IS NOT NULL LIMIT ?',
        (limit,),
    ).fetchall()
    return [r["v"] for r in rows]


def _row_count(conn: sqlite3.Connection, table: str) -> int:
    return conn.execute(f'SELECT COUNT(*) AS c FROM "{table}"').fetchone()["c"]


def _columns(
    conn: sqlite3.Connection, table: str, limit: int, pk: list[str]
) -> list[dict]:
    info = conn.execute(f'PRAGMA table_info("{table}")').fetchall()
    comments = _column_comments(conn, table)
    pk_set = set(pk)
    cols = []
    for r in info:
        # SQLite reports an INTEGER PRIMARY KEY column as notnull=0 (rowid alias),
        # but a primary-key column is never nullable — correct that here.
        nullable = not bool(r["notnull"]) and r["name"] not in pk_set
        cols.append(
            {
                "name": r["name"],
                "sql_type": (r["type"] or "").upper() or "UNKNOWN",
                "nullable": nullable,
                "comment": comments.get(r["name"]),
                "samples": _column_samples(conn, table, r["name"], limit),
            }
        )
    return cols


def _is_lookup(conn: sqlite3.Connection, table: str, fk_targets: set[str]) -> dict | None:
    """Detect a lookup table and return its contents block, or None.

    Heuristic (spec section 9.4): a code+label shape (two non-key-ish columns,
    one integer code, one text label) that is either small (<= LOOKUP_MAX_ROWS)
    or an FK target.
    """
    info = conn.execute(f'PRAGMA table_info("{table}")').fetchall()
    if len(info) != 2:
        return None

    row_count = _row_count(conn, table)
    small = row_count <= config.LOOKUP_MAX_ROWS
    if not (small or table in fk_targets):
        return None

    # Identify a code column (integer, often the PK) and a text display column.
    code_col = next((r["name"] for r in info if r["pk"]), None)
    if code_col is None:
        code_col = next(
            (r["name"] for r in info if "INT" in (r["type"] or "").upper()), None
        )
    display_col = next((r["name"] for r in info if r["name"] != code_col), None)
    if not code_col or not display_col:
        return None

    rows = conn.execute(
        f'SELECT "{code_col}" AS code, "{display_col}" AS display FROM "{table}" '
        f"ORDER BY 1 LIMIT ?",
        (config.LOOKUP_MAX_ROWS,),
    ).fetchall()
    return {
        "table": table,
        "code_column": code_col,
        "display_column": display_col,
        "values": [{"code": r["code"], "display": r["display"]} for r in rows],
    }


def extract(
    db_path: Path | str = config.SOURCE_DB_PATH,
    *,
    engine: str = "sqlite",
    database: str | None = None,
    sample_limit: int = config.VALUE_SAMPLE_LIMIT,
) -> dict:
    """Extract catalog metadata from ``db_path`` into the source_metadata dict."""
    db_path = Path(db_path)
    if not db_path.exists():
        raise FileNotFoundError(f"source database not found: {db_path}")

    conn = _connect_readonly(db_path)
    try:
        table_names = _list_tables(conn)

        # First pass: collect FK targets so we can classify lookups.
        fk_targets: set[str] = set()
        fks_by_table: dict[str, list[dict]] = {}
        for t in table_names:
            fks = _foreign_keys(conn, t)
            fks_by_table[t] = fks
            for fk in fks:
                fk_targets.add(fk["ref_table"])

        tables = []
        lookups = []
        for t in table_names:
            lookup = _is_lookup(conn, t, fk_targets)
            if lookup is not None:
                lookups.append(lookup)
                # Lookup tables are still emitted as tables too, so the agent can
                # see their shape; their contents additionally live in `lookups`.
            pk = _primary_key(conn, t)
            tables.append(
                {
                    "name": t,
                    "comment": _table_comment(conn, t),
                    "primary_key": pk,
                    "columns": _columns(conn, t, sample_limit, pk),
                    "foreign_keys": fks_by_table[t],
                }
            )

        return {
            "engine": engine,
            "database": database or db_path.stem,
            "tables": tables,
            "lookups": lookups,
        }
    finally:
        conn.close()


def extract_to_file(
    db_path: Path | str = config.SOURCE_DB_PATH,
    out_path: Path | str = config.SOURCE_METADATA_PATH,
    **kwargs,
) -> Path:
    data = extract(db_path, **kwargs)
    out_path = Path(out_path)
    out_path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    return out_path


if __name__ == "__main__":
    path = extract_to_file()
    print(f"source_metadata written to {path}")
