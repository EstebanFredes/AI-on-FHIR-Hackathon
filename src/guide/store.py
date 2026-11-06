"""Step 3 — the implementation-guide store.

Loads the three CSVs of the Bupa Chile Core Implementation Guide into SQLite and
exposes the Phase B query methods the agent's tools call. Everything factual the
agent reports (type, min/max, binding, fixed value, terminology codes) comes
from here — never from the model's memory (spec section 7.2).

The real CSV column headers are not known ahead of time, so the loader is
schema-tolerant: it loads each CSV verbatim, then *resolves* the logical columns
the tools need (profile, element, min, max, ...) against the actual headers
using a candidate-name list. You can override the mapping in guide/columns.json
(see guide/README.md). This means the same code works whether the headers are
Spanish or English, with or without accents.
"""

from __future__ import annotations

import csv
import json
import re
import sqlite3
import unicodedata
from pathlib import Path

import config

# ---------------------------------------------------------------------------
# Logical column -> candidate header names (normalised comparison, see _norm).
# Order matters: the first candidate that matches an actual header wins.
# ---------------------------------------------------------------------------
CANDIDATES: dict[str, dict[str, list[str]]] = {
    "campos": {
        "profile": ["perfil", "profile", "perfil_id", "recurso_perfil", "id_perfil"],
        "element": ["elemento", "element", "path", "ruta", "elemento_path", "campo_fhir"],
        "min": ["min", "minimo", "cardinalidad_min", "card_min"],
        "max": ["max", "maximo", "cardinalidad_max", "card_max"],
        "type": ["tipo", "type", "tipo_dato", "datatype", "tipo_fhir"],
        "binding": ["binding", "valueset", "value_set", "conjunto_valores", "vinculacion", "binding_valueset"],
        "binding_strength": ["fuerza", "strength", "binding_strength", "fuerza_binding"],
        "fixed": ["fijo", "fixed", "valor_fijo", "fixedvalue", "patron", "pattern"],
        "must_support": ["mustsupport", "must_support", "soporte", "debe_soportar", "ms"],
        "logical_model": ["modelo_logico", "modelo", "logical_model", "modelo_id"],
    },
    "modelos": {
        "logical_model": ["modelo_logico", "modelo", "logical_model", "modelo_id"],
        "field": ["campo", "field", "elemento", "atributo", "nombre_campo"],
        "definition": ["definicion", "descripcion", "definition", "description", "significado", "glosa"],
        "type": ["tipo", "type", "tipo_dato", "datatype"],
    },
    "terminologias": {
        "valueset": ["conjunto", "valueset", "value_set", "conjunto_valores", "nombre_conjunto", "sistema", "codesystem"],
        "code": ["codigo", "code", "valor", "cod"],
        "display": ["display", "etiqueta", "descripcion", "glosa", "nombre", "label", "significado"],
        "system": ["sistema", "system", "codesystem", "url_sistema"],
    },
}


def _norm(s: str) -> str:
    """Lowercase, strip accents, drop non-alphanumerics for tolerant matching."""
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]", "", s.lower())


def _sanitize_identifier(header: str) -> str:
    ident = re.sub(r"[^0-9a-zA-Z_]", "_", header.strip())
    if not ident:
        ident = "col"
    if ident[0].isdigit():
        ident = "c_" + ident
    return ident


class GuideNotLoadedError(RuntimeError):
    pass


class GuideStore:
    """Read access to the guide, backed by the SQLite file at GUIDE_DB_PATH."""

    def __init__(self, db_path: Path | str = config.GUIDE_DB_PATH):
        self.db_path = Path(db_path)
        self._conn: sqlite3.Connection | None = None
        # resolved[table][logical] = actual sanitized column name (or None)
        self.resolved: dict[str, dict[str, str | None]] = {}

    # --- connection ---------------------------------------------------------
    @property
    def conn(self) -> sqlite3.Connection:
        if self._conn is None:
            if not self.db_path.exists():
                raise GuideNotLoadedError(
                    f"guide database not found at {self.db_path}. "
                    "Run the loader first (python -m src.guide.load_guide)."
                )
            self._conn = sqlite3.connect(f"file:{self.db_path.as_posix()}?mode=ro", uri=True)
            self._conn.row_factory = sqlite3.Row
            self._load_resolved()
        return self._conn

    def close(self) -> None:
        if self._conn is not None:
            self._conn.close()
            self._conn = None

    def _load_resolved(self) -> None:
        row = self._conn.execute(
            "SELECT value FROM _meta WHERE key = 'resolved'"
        ).fetchone()
        if row:
            self.resolved = json.loads(row["value"])

    # --- helpers ------------------------------------------------------------
    def _col(self, table: str, logical: str) -> str:
        _ = self.conn  # ensure the connection is open and `resolved` is loaded
        actual = self.resolved.get(table, {}).get(logical)
        if not actual:
            raise GuideNotLoadedError(
                f"column '{logical}' could not be resolved for table '{table}'. "
                "Set it explicitly in guide/columns.json."
            )
        return actual

    def _has(self, table: str, logical: str) -> bool:
        _ = self.conn  # ensure the connection is open and `resolved` is loaded
        return bool(self.resolved.get(table, {}).get(logical))

    def _rows(self, sql: str, params: tuple = ()) -> list[dict]:
        return [dict(r) for r in self.conn.execute(sql, params).fetchall()]

    # --- Phase B query methods ---------------------------------------------
    def consultar_campo(
        self,
        profile: str | None = None,
        element: str | None = None,
        required: bool | None = None,
        must_support: bool | None = None,
        has_binding: bool | None = None,
    ) -> list[dict]:
        """Rows from `campos`: min/max, type, binding, fixed value, logical model."""
        p = self._col("campos", "profile")
        e = self._col("campos", "element")
        where, params = [], []
        if profile:
            where.append(f'"{p}" LIKE ?')
            params.append(f"%{profile}%")
        if element:
            where.append(f'"{e}" LIKE ?')
            params.append(f"%{element}%")
        if required is not None and self._has("campos", "min"):
            mn = self._col("campos", "min")
            if required:
                where.append(f'CAST("{mn}" AS INTEGER) >= 1')
            else:
                where.append(f'(CAST("{mn}" AS INTEGER) = 0 OR "{mn}" IS NULL)')
        if must_support is not None and self._has("campos", "must_support"):
            ms = self._col("campos", "must_support")
            op = "IN" if must_support else "NOT IN"
            where.append(f'LOWER("{ms}") {op} (\'true\',\'1\',\'y\',\'yes\',\'si\')')
        if has_binding is not None and self._has("campos", "binding"):
            b = self._col("campos", "binding")
            where.append(f'("{b}" IS NOT NULL AND "{b}" <> "")' if has_binding
                         else f'("{b}" IS NULL OR "{b}" = "")')
        sql = 'SELECT rowid AS _row, * FROM campos'
        if where:
            sql += " WHERE " + " AND ".join(where)
        sql += " LIMIT 200"
        return self._rows(sql, tuple(params))

    def ver_modelo_logico(
        self, logical_model: str | None = None, field: str | None = None
    ) -> list[dict]:
        """Business-language field definitions from `modelos`."""
        where, params = [], []
        if logical_model:
            m = self._col("modelos", "logical_model")
            where.append(f'"{m}" LIKE ?')
            params.append(f"%{logical_model}%")
        if field:
            f = self._col("modelos", "field")
            where.append(f'"{f}" LIKE ?')
            params.append(f"%{field}%")
        sql = "SELECT rowid AS _row, * FROM modelos"
        if where:
            sql += " WHERE " + " AND ".join(where)
        sql += " LIMIT 200"
        return self._rows(sql, tuple(params))

    def buscar_binding(self, valueset: str) -> list[dict]:
        """Terminology codes + display for a value set, from `terminologias`."""
        vs = self._col("terminologias", "valueset")
        sql = f'SELECT rowid AS _row, * FROM terminologias WHERE "{vs}" LIKE ? LIMIT 500'
        return self._rows(sql, (f"%{valueset}%",))

    def listar_perfiles_por_dominio(self, domain: str | None = None) -> list[dict]:
        """Candidate profiles, optionally filtered by a domain/resource substring."""
        p = self._col("campos", "profile")
        if domain:
            sql = (
                f'SELECT DISTINCT "{p}" AS profile FROM campos '
                f'WHERE "{p}" LIKE ? ORDER BY 1 LIMIT 200'
            )
            return self._rows(sql, (f"%{domain}%",))
        sql = f'SELECT DISTINCT "{p}" AS profile FROM campos ORDER BY 1 LIMIT 200'
        return self._rows(sql)

    def buscar_en_guia(self, query: str, limit: int = 15) -> list[dict]:
        """Natural-language search over narrative pages and guide rows.

        Narrative pages (guide/narrative/*.md|txt) are searched first; otherwise
        we fall back to a LIKE search over element names and field definitions,
        returning a synthetic 'section path' so citations stay traceable.
        """
        results: list[dict] = []
        terms = [t for t in re.split(r"\s+", query.strip()) if t]
        if self._table_exists("narrative"):
            like = " OR ".join(["body LIKE ?"] * len(terms)) or "1=1"
            params = [f"%{t}%" for t in terms]
            rows = self.conn.execute(
                f"SELECT source, section, body FROM narrative WHERE {like} LIMIT ?",
                (*params, limit),
            ).fetchall()
            for r in rows:
                snippet = r["body"]
                results.append(
                    {
                        "section_path": f'{r["source"]} / {r["section"]}',
                        "text": snippet[:600],
                    }
                )
        if len(results) < limit:
            # Fall back to element rows from campos (FHIR element names).
            e = self.resolved.get("campos", {}).get("element")
            p = self.resolved.get("campos", {}).get("profile")
            if e and p:
                like = " OR ".join([f'"{e}" LIKE ?'] * len(terms)) or "1=1"
                params = [f"%{t}%" for t in terms]
                rows = self.conn.execute(
                    f'SELECT "{p}" AS profile, "{e}" AS element FROM campos '
                    f"WHERE {like} LIMIT ?",
                    (*params, limit - len(results)),
                ).fetchall()
                for r in rows:
                    results.append(
                        {
                            "section_path": f'campos_perfiles / {r["profile"]}',
                            "text": f'Element {r["element"]} in profile {r["profile"]}',
                        }
                    )
        if len(results) < limit:
            # Also search the logical-model definitions (business-language terms).
            m = self.resolved.get("modelos", {}).get("logical_model")
            f = self.resolved.get("modelos", {}).get("field")
            d = self.resolved.get("modelos", {}).get("definition")
            if m and f:
                search_cols = [c for c in (f, d) if c]
                clause = " OR ".join(
                    f'"{c}" LIKE ?' for c in search_cols for _ in terms
                ) or "1=1"
                params = [f"%{t}%" for c in search_cols for t in terms]
                sel_d = f'"{d}"' if d else "''"
                rows = self.conn.execute(
                    f'SELECT "{m}" AS model, "{f}" AS field, {sel_d} AS definition '
                    f"FROM modelos WHERE {clause} LIMIT ?",
                    (*params, limit - len(results)),
                ).fetchall()
                for r in rows:
                    results.append(
                        {
                            "section_path": f'modelos_logicos / {r["model"]}',
                            "text": f'{r["field"]}: {r["definition"]}',
                        }
                    )
        return results

    def _table_exists(self, name: str) -> bool:
        row = self.conn.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name = ?", (name,)
        ).fetchone()
        return row is not None
