"""Step 3 (loader) — load the guide CSVs into the SQLite guide store.

Reads the three CSVs named in config.GUIDE_CSVS, loads each verbatim into a
table (`campos`, `modelos`, `terminologias`), resolves the logical columns the
tools need against the real headers, and persists that resolution in a `_meta`
table so GuideStore can read it back. Any markdown/text files under
guide/narrative/ are indexed into a `narrative` table for buscar_en_guia.

Run:  python -m src.guide.load_guide
"""

from __future__ import annotations

import csv
import json
import sqlite3
from pathlib import Path

import config
from src.guide.store import CANDIDATES, _norm, _sanitize_identifier


def _read_csv(path: Path) -> tuple[list[str], list[dict]]:
    with path.open(newline="", encoding="utf-8-sig") as fh:
        reader = csv.DictReader(fh)
        headers = reader.fieldnames or []
        rows = [dict(r) for r in reader]
    return headers, rows


def _resolve_columns(table: str, sanitized_headers: list[str]) -> dict[str, str | None]:
    """Map each logical column to an actual (sanitized) header, or None."""
    norm_to_actual = {_norm(h): h for h in sanitized_headers}
    out: dict[str, str | None] = {}
    for logical, candidates in CANDIDATES[table].items():
        match = None
        for cand in candidates:
            n = _norm(cand)
            if n in norm_to_actual:
                match = norm_to_actual[n]
                break
        if match is None:
            # Looser pass: substring match on normalised names.
            for cand in candidates:
                n = _norm(cand)
                for hn, actual in norm_to_actual.items():
                    if n and (n in hn or hn in n):
                        match = actual
                        break
                if match:
                    break
        out[logical] = match
    return out


def _load_table(conn: sqlite3.Connection, table: str, path: Path) -> dict[str, str | None]:
    headers, rows = _read_csv(path)
    sanitized = [_sanitize_identifier(h) for h in headers]
    # De-duplicate sanitized names.
    seen: dict[str, int] = {}
    final_cols = []
    for s in sanitized:
        if s in seen:
            seen[s] += 1
            final_cols.append(f"{s}_{seen[s]}")
        else:
            seen[s] = 0
            final_cols.append(s)

    conn.execute(f"DROP TABLE IF EXISTS {table}")
    col_defs = ", ".join(f'"{c}" TEXT' for c in final_cols)
    conn.execute(f"CREATE TABLE {table} ({col_defs})")
    placeholders = ", ".join("?" for _ in final_cols)
    for r in rows:
        values = [r.get(h) for h in headers]
        conn.execute(f"INSERT INTO {table} VALUES ({placeholders})", values)

    resolved = _resolve_columns(table, final_cols)
    return resolved


def _index_narrative(conn: sqlite3.Connection) -> int:
    narrative_dir = config.GUIDE_NARRATIVE_DIR
    conn.execute("DROP TABLE IF EXISTS narrative")
    conn.execute("CREATE TABLE narrative (source TEXT, section TEXT, body TEXT)")
    if not narrative_dir.exists():
        return 0
    count = 0
    for path in sorted(narrative_dir.glob("*")):
        if path.suffix.lower() not in {".md", ".txt"}:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        # Split on markdown headings so each section is independently searchable.
        section = "(intro)"
        buf: list[str] = []

        def flush():
            nonlocal count, buf, section
            body = "\n".join(buf).strip()
            if body:
                conn.execute(
                    "INSERT INTO narrative VALUES (?, ?, ?)", (path.name, section, body)
                )
                count += 1
            buf = []

        for line in text.splitlines():
            if line.lstrip().startswith("#"):
                flush()
                section = line.lstrip("#").strip() or section
            else:
                buf.append(line)
        flush()
    return count


def load(
    csvs: dict[str, Path] | None = None,
    db_path: Path | str = config.GUIDE_DB_PATH,
) -> dict:
    """Load the guide CSVs into the SQLite store. Returns a summary dict."""
    csvs = csvs or config.GUIDE_CSVS
    db_path = Path(db_path)

    missing = {name: str(p) for name, p in csvs.items() if not Path(p).exists()}
    if missing:
        raise FileNotFoundError(
            "guide CSV(s) not found: "
            + ", ".join(f"{k}={v}" for k, v in missing.items())
            + ". Place the Implementation Guide CSVs in guide/ (see guide/README.md)."
        )

    # Optional per-table column overrides from guide/columns.json.
    overrides: dict[str, dict[str, str]] = {}
    if config.GUIDE_COLUMNS_CONFIG.exists():
        overrides = json.loads(config.GUIDE_COLUMNS_CONFIG.read_text(encoding="utf-8"))

    if db_path.exists():
        db_path.unlink()
    conn = sqlite3.connect(db_path)
    try:
        resolved_all: dict[str, dict[str, str | None]] = {}
        counts: dict[str, int] = {}
        for table, path in csvs.items():
            resolved = _load_table(conn, table, Path(path))
            # Apply explicit overrides on top of auto-resolution.
            for logical, actual in overrides.get(table, {}).items():
                resolved[logical] = _sanitize_identifier(actual)
            resolved_all[table] = resolved
            counts[table] = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]

        narrative_sections = _index_narrative(conn)

        conn.execute("CREATE TABLE _meta (key TEXT PRIMARY KEY, value TEXT)")
        conn.execute(
            "INSERT INTO _meta VALUES ('resolved', ?)",
            (json.dumps(resolved_all, ensure_ascii=False),),
        )
        conn.commit()

        return {
            "db_path": str(db_path),
            "row_counts": counts,
            "narrative_sections": narrative_sections,
            "resolved_columns": resolved_all,
        }
    finally:
        conn.close()


if __name__ == "__main__":
    summary = load()
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    # Warn loudly about any logical column that did not resolve.
    for table, cols in summary["resolved_columns"].items():
        unresolved = [k for k, v in cols.items() if not v]
        if unresolved:
            print(
                f"[warn] table '{table}': could not resolve {unresolved}. "
                "Set them in guide/columns.json if the tools need them."
            )
