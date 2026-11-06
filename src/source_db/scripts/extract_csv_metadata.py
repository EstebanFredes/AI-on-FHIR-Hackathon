#!/usr/bin/env python3
"""
Extract metadata from the spreadsheet vocabularies (vocab/*.csv).

For every CSV it detects the file format (encoding, delimiter, line endings),
then profiles each column: inferred data type, nullability, distinct values,
lengths, min/max, value pattern, a guess of the standard code system the values
look like (LOINC, ICD-10-CM, CPT/HCPCS, ...) and sample values.

Outputs (in csv-metadata/, overwritten on every run):
  <file>.json      full metadata of one CSV
  <file>.sql       suggested CREATE TABLE for loading that CSV into Postgres
  _columns.csv     one row per column across all files (easy to diff/filter)

Usage:  python3 scripts/extract_csv_metadata.py [input_dir] [output_dir]
        (defaults: vocab  csv-metadata, relative to the project root)
Only the Python standard library is used.
"""
import csv
import json
import re
import sys
from collections import Counter
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IN_DIR = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "vocab"
OUT_DIR = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "csv-metadata"

# kept narrow on purpose: "NA" is sodium in a lab file, "N/A" a gram reaction, "-" a placeholder code
NULL_TOKENS = {"", "null", "NULL"}
DELIMITERS = [",", ";", "\t", "|"]
SAMPLE_SIZE = 5
ENUM_MAX_DISTINCT = 12       # report full value list when a column has at most this many distinct values
SEMANTIC_THRESHOLD = 0.9     # share of non-null values that must match a code pattern

# date formats tried in order; the first one that parses every non-null value wins
DATE_FORMATS = [
    ("%Y-%m-%d", "YYYY-MM-DD", "date"),
    ("%m/%d/%Y", "MM/DD/YYYY", "date"),
    ("%d.%m.%Y", "DD.MM.YYYY", "date"),
    ("%Y-%m-%d %H:%M:%S", "YYYY-MM-DD HH:MI:SS", "timestamp"),
    ("%Y-%m", "YYYY-MM", "year_month"),
]
BOOL_SETS = [{"Y", "N"}, {"YES", "NO"}, {"TRUE", "FALSE"}, {"T", "F"}, {"1", "0"}]

# code-system guesses: (name, value regex, column-name regex or None).
# Order matters: first match above threshold wins. Digit-only systems (SNOMED CT) are too
# ambiguous to guess from values alone, so they also require a matching column name.
SEMANTIC_PATTERNS = [
    ("loinc",           re.compile(r"^\d{1,6}-\d$"), None),
    ("icd10cm",         re.compile(r"^[A-TV-Z]\d[0-9A-Z](\.[0-9A-Z]{1,4})?$"), None),
    ("cpt_hcpcs",       re.compile(r"^(\d{4}[0-9A-Z]|[A-V]\d{4})$"), None),
    ("ub04_revenue",    re.compile(r"^0\d{3}$"), None),
    ("snomed_ct",       re.compile(r"^\d{6,18}$"), re.compile(r"snomed|sct", re.I)),
    ("rxnorm",          re.compile(r"^\d{1,7}$"), re.compile(r"rxnorm|rxcui", re.I)),
    ("cost_center",     re.compile(r"^CC-\d{4}$"), None),
    ("person_initials", re.compile(r"^[A-Z]\. [A-Z][a-zA-Z'-]+$"), None),
]
# column names that mean "identifier/code": keep as text even if the values are numeric
CODE_NAME_HINT = re.compile(r"(code|number|num\b|#|_id\b|\bid\b|cpt|rev)", re.I)


def detect_format(path: Path) -> dict:
    raw = path.read_bytes()
    encoding = "utf-8-sig" if raw.startswith(b"\xef\xbb\xbf") else "utf-8"
    try:
        text = raw.decode(encoding)
    except UnicodeDecodeError:
        encoding, text = "latin-1", raw.decode("latin-1")
    line_ending = "CRLF" if "\r\n" in text else "LF"
    try:
        delimiter = csv.Sniffer().sniff(text.split("\n", 1)[0], delimiters="".join(DELIMITERS)).delimiter
    except csv.Error:
        delimiter = ","
    return {"encoding": encoding, "delimiter": delimiter, "line_ending": line_ending,
            "size_bytes": len(raw), "text": text}


def snake(name: str) -> str:
    s = name.strip().replace("#", "_no").replace("%", "pct")
    s = re.sub(r"\(([^)]*)\)", r"_\1", s)
    s = re.sub(r"[^0-9a-zA-Z]+", "_", s).strip("_").lower()
    return s if not s[:1].isdigit() else f"c_{s}"


def is_int(v: str) -> bool:
    return re.fullmatch(r"[+-]?\d+", v) is not None


def to_decimal(v: str):
    try:
        return Decimal(v.replace(",", "")) if re.fullmatch(r"[+-]?[\d,]*\.?\d+", v) else None
    except InvalidOperation:
        return None


def value_shape(v: str) -> str:
    """Collapse a value into a shape: A = letter, 9 = digit, other chars kept."""
    s = re.sub(r"[A-Za-z]", "A", v)
    s = re.sub(r"\d", "9", s)
    return re.sub(r"(A{4,}|9{4,})", lambda m: f"{m.group(0)[0]}{{{len(m.group(0))}}}", s)


def infer(name: str, values: list) -> dict:
    """Infer type + profile for one column. `values` are raw strings (nulls included)."""
    non_null = [v for v in values if v.strip() not in NULL_TOKENS]
    nn = [v.strip() for v in non_null]
    info = {
        "null_count": len(values) - len(nn),
        "nullable": len(nn) < len(values),
        "distinct_count": len(set(nn)),
        "unique": len(set(nn)) == len(nn) and len(nn) > 0,
        "min_length": min((len(v) for v in nn), default=0),
        "max_length": max((len(v) for v in nn), default=0),
    }
    if not nn:
        info.update(inferred_type="unknown", sql_type="text", note="column is empty")
        return info

    upper = {v.upper() for v in nn}
    leading_zero = any(re.fullmatch(r"0\d+", v) for v in nn)

    # boolean
    if any(upper <= s for s in BOOL_SETS) and len(upper) <= 2 and not all(is_int(v) for v in nn) or upper <= {"Y", "N"}:
        info.update(inferred_type="boolean", sql_type="boolean", true_false_tokens=sorted(upper))
    # integer
    elif all(is_int(v) for v in nn):
        if leading_zero or CODE_NAME_HINT.search(name):
            info.update(inferred_type="code", sql_type=f"varchar({info['max_length']})",
                        note="numeric-looking identifier kept as text" + (" (leading zeros)" if leading_zero else ""))
        else:
            ints = [int(v) for v in nn]
            info.update(inferred_type="integer", sql_type="bigint" if max(map(abs, ints)) > 2**31 - 1 else "integer",
                        min=min(ints), max=max(ints))
    # decimal
    elif all(to_decimal(v) is not None for v in nn):
        decs = [to_decimal(v) for v in nn]
        scale = max(max(-d.as_tuple().exponent, 0) for d in decs)
        precision = max(len(d.as_tuple().digits) for d in decs) + 2
        info.update(inferred_type="decimal", sql_type=f"numeric({max(precision, scale + 1)},{scale})",
                    min=str(min(decs)), max=str(max(decs)))
    else:
        # dates
        for fmt, label, kind in DATE_FORMATS:
            try:
                parsed = [datetime.strptime(v, fmt) for v in nn]
            except ValueError:
                continue
            sql = {"date": "date", "timestamp": "timestamp", "year_month": "varchar(7)"}[kind]
            info.update(inferred_type=kind, sql_type=sql, date_format=label,
                        min=min(parsed).strftime(fmt), max=max(parsed).strftime(fmt))
            if kind == "year_month":
                info["note"] = "year-month only; Postgres date rejects it - kept as text (to_date(col,'YYYY-MM') to convert)"
            elif label == "MM/DD/YYYY":
                info["note"] = "US date order; loads as date only with DateStyle MDY (Postgres default)"
            break
        else:
            info.update(inferred_type="string", sql_type=f"varchar({info['max_length']})" if info["max_length"] <= 255 else "text")

    # semantic guess (code system / pattern), on the stripped non-null values
    for sem, rx, name_rx in SEMANTIC_PATTERNS:
        if name_rx and not name_rx.search(name):
            continue
        hits = sum(1 for v in nn if rx.match(v))
        if hits / len(nn) >= SEMANTIC_THRESHOLD:
            info["semantic_hint"] = sem
            if hits < len(nn):
                info["semantic_outliers"] = sorted({v for v in nn if not rx.match(v)})
            if info["inferred_type"] in ("integer",):
                info.update(inferred_type="code", sql_type=f"varchar({info['max_length']})")
            break

    shapes = Counter(value_shape(v) for v in nn)
    info["value_shapes"] = dict(shapes.most_common(5))
    if info["distinct_count"] <= ENUM_MAX_DISTINCT and info["inferred_type"] in ("string", "code", "boolean") \
            and info["distinct_count"] < len(nn):
        info["enum_values"] = dict(Counter(nn).most_common())
    info["sample_values"] = list(dict.fromkeys(nn))[:SAMPLE_SIZE]
    info["has_untrimmed_whitespace"] = any(v != v.strip() for v in non_null)
    return info


def profile(path: Path) -> dict:
    fmt = detect_format(path)
    rows = list(csv.reader(fmt.pop("text").splitlines(), delimiter=fmt["delimiter"]))
    header, data = rows[0], [r for r in rows[1:] if any(c.strip() for c in r)]
    widths = Counter(len(r) for r in data)
    columns = []
    for i, name in enumerate(header):
        col_values = [r[i] if i < len(r) else "" for r in data]
        columns.append({"position": i + 1, "name": name, "sql_name": snake(name), **infer(name, col_values)})

    # candidate primary key: first unique, non-null column
    pk = next((c["name"] for c in columns if c["unique"] and not c["nullable"]), None)
    return {
        "file": path.name,
        "extracted_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "format": fmt,
        "row_count": len(data),
        "column_count": len(header),
        "ragged_rows": {str(k): v for k, v in widths.items() if k != len(header)},
        "candidate_primary_key": pk,
        "header_style": ("UPPER_SNAKE" if all(re.fullmatch(r"[A-Z0-9_]+", h) for h in header)
                         else "lower_snake" if all(re.fullmatch(r"[a-z0-9_]+", h) for h in header)
                         else "free text"),
        "columns": columns,
    }


def ddl(meta: dict) -> str:
    table = "vocab." + snake(Path(meta["file"]).stem)
    lines = []
    for c in meta["columns"]:
        notes = [c["inferred_type"]]
        if c.get("semantic_hint"):
            notes.append(c["semantic_hint"])
        if c.get("date_format"):
            notes.append(c["date_format"])
        if c["name"] != c["sql_name"]:
            notes.append(f'source column "{c["name"]}"')
        null = "" if c["nullable"] else " NOT NULL"
        lines.append(f'  {c["sql_name"]:<28} {c["sql_type"]}{null},  -- {", ".join(notes)}')
    if meta["candidate_primary_key"]:
        pk = next(c["sql_name"] for c in meta["columns"] if c["name"] == meta["candidate_primary_key"])
        lines.append(f"  PRIMARY KEY ({pk})")
    else:
        lines[-1] = lines[-1].replace(",  --", "   --", 1)
    f = meta["format"]
    delim = {"\t": "E'\\t'"}.get(f["delimiter"], f"'{f['delimiter']}'")
    return (f"-- generated from {meta['file']} ({meta['row_count']} rows) by scripts/extract_csv_metadata.py\n"
            f"-- types are inferred from the data; review before use\n"
            f"CREATE SCHEMA IF NOT EXISTS vocab;\n"
            f"CREATE TABLE {table} (\n" + "\n".join(lines) + "\n);\n"
            f"-- \\copy {table} FROM 'vocab/{meta['file']}' WITH (FORMAT csv, HEADER true, DELIMITER {delim})\n")


def main() -> None:
    files = sorted(IN_DIR.glob("*.csv"))
    if not files:
        sys.exit(f"no CSV files in {IN_DIR}")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for old in OUT_DIR.glob("*"):          # rerunnable: drop outputs of removed CSVs
        if old.suffix in (".json", ".sql") or old.name == "_columns.csv":
            old.unlink()

    summary_rows = []
    for path in files:
        meta = profile(path)
        stem = path.stem
        (OUT_DIR / f"{stem}.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n")
        (OUT_DIR / f"{stem}.sql").write_text(ddl(meta))
        for c in meta["columns"]:
            summary_rows.append({
                "file": meta["file"], "position": c["position"], "column": c["name"], "sql_name": c["sql_name"],
                "inferred_type": c["inferred_type"], "sql_type": c["sql_type"],
                "semantic_hint": c.get("semantic_hint", ""), "date_format": c.get("date_format", ""),
                "nullable": c["nullable"], "null_count": c["null_count"], "distinct_count": c["distinct_count"],
                "unique": c["unique"], "max_length": c["max_length"],
                "min": c.get("min", ""), "max": c.get("max", ""),
                "sample_values": " | ".join(map(str, c["sample_values"])) if "sample_values" in c else "",
            })
        print(f"{path.name:<40} {meta['row_count']:>4} rows  {meta['column_count']:>2} cols  "
              f"delim={meta['format']['delimiter']!r}  pk={meta['candidate_primary_key']}")

    with open(OUT_DIR / "_columns.csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(summary_rows[0].keys()))
        w.writeheader()
        w.writerows(summary_rows)
    print(f"\nwrote {len(files)} json + {len(files)} sql + _columns.csv to {OUT_DIR}")


if __name__ == "__main__":
    main()
