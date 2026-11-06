"""Step 1 (fixture) — build a synthetic source database in SQLite.

The spec (section 8) calls for a one-time synthetic source so the rest of the
pipeline has something real to read: declared PK/FK, lookup tables, and
synthetic rows. We model a small scheduling domain with several entities so the
agent has more than one candidate entity to group:

    patient              — the subject of care
    practitioner         — the clinician
    location             — where the appointment happens
    appointment_status   — lookup (code + label)
    appointment_type     — lookup (code + label)
    appointment          — the main fact table, with FKs to all of the above

SQLite has no native column/table comments, so we persist them in two side
tables (`_table_meta`, `_column_meta`). The extractor reads these back to honour
the `comment` fields of the source_metadata contract. Names starting with "_"
are treated as internal and never emitted as source tables.

Everything here is synthetic (spec section 7.6 — synthetic data only).
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

import config

# (table_name, comment, create_sql, column_comments)
_SCHEMA: list[tuple[str, str, str, dict[str, str]]] = [
    (
        "patient",
        "Patients registered in the scheduling system",
        """
        CREATE TABLE patient (
            patient_id   INTEGER PRIMARY KEY,
            national_id  TEXT    NOT NULL,
            first_name   TEXT    NOT NULL,
            last_name    TEXT    NOT NULL,
            birth_date   TEXT    NOT NULL,
            sex          TEXT    NOT NULL,
            email        TEXT,
            phone        TEXT
        )
        """,
        {
            "patient_id": "Internal patient identifier",
            "national_id": "National identity number (RUT)",
            "first_name": "Patient given name",
            "last_name": "Patient family name",
            "birth_date": "Date of birth (YYYY-MM-DD)",
            "sex": "Administrative sex: M/F/O",
            "email": "Contact email",
            "phone": "Contact phone number",
        },
    ),
    (
        "practitioner",
        "Clinicians who attend appointments",
        """
        CREATE TABLE practitioner (
            practitioner_id INTEGER PRIMARY KEY,
            national_id     TEXT    NOT NULL,
            full_name       TEXT    NOT NULL,
            specialty       TEXT    NOT NULL
        )
        """,
        {
            "practitioner_id": "Internal practitioner identifier",
            "national_id": "National identity number (RUT)",
            "full_name": "Practitioner full name",
            "specialty": "Clinical specialty description",
        },
    ),
    (
        "location",
        "Physical locations / consulting rooms",
        """
        CREATE TABLE location (
            location_id INTEGER PRIMARY KEY,
            name        TEXT NOT NULL,
            building    TEXT,
            floor       TEXT
        )
        """,
        {
            "location_id": "Internal location identifier",
            "name": "Consulting room / location name",
            "building": "Building name",
            "floor": "Floor label",
        },
    ),
    (
        "appointment_status",
        "Lookup: appointment status codes",
        """
        CREATE TABLE appointment_status (
            id    INTEGER PRIMARY KEY,
            label TEXT NOT NULL
        )
        """,
        {
            "id": "Status code",
            "label": "Human-readable status label",
        },
    ),
    (
        "appointment_type",
        "Lookup: appointment type codes",
        """
        CREATE TABLE appointment_type (
            id    INTEGER PRIMARY KEY,
            label TEXT NOT NULL
        )
        """,
        {
            "id": "Type code",
            "label": "Human-readable type label",
        },
    ),
    (
        "appointment",
        "Scheduled appointments",
        """
        CREATE TABLE appointment (
            appointment_id  INTEGER PRIMARY KEY,
            start_ts        TEXT    NOT NULL,
            end_ts          TEXT,
            status_id       INTEGER NOT NULL,
            type_id         INTEGER,
            patient_id      INTEGER NOT NULL,
            practitioner_id INTEGER,
            location_id     INTEGER,
            reason_text     TEXT,
            legacy_flag     INTEGER,
            created_at      TEXT    NOT NULL,
            FOREIGN KEY (status_id)       REFERENCES appointment_status(id),
            FOREIGN KEY (type_id)         REFERENCES appointment_type(id),
            FOREIGN KEY (patient_id)      REFERENCES patient(patient_id),
            FOREIGN KEY (practitioner_id) REFERENCES practitioner(practitioner_id),
            FOREIGN KEY (location_id)     REFERENCES location(location_id)
        )
        """,
        {
            "appointment_id": "Internal appointment identifier",
            "start_ts": "Appointment start date/time",
            "end_ts": "Appointment end date/time",
            "status_id": "Appointment status (FK to appointment_status)",
            "type_id": "Appointment type (FK to appointment_type)",
            "patient_id": "Patient reference (FK to patient)",
            "practitioner_id": "Attending practitioner (FK to practitioner)",
            "location_id": "Location reference (FK to location)",
            "reason_text": "Free-text reason for the visit",
            "legacy_flag": "Legacy migration flag (no current meaning)",
            "created_at": "Row creation timestamp",
        },
    ),
]

_ROWS: dict[str, list[tuple]] = {
    "patient": [
        (10432, "11.111.111-1", "Camila", "Rojas", "1988-03-12", "F", "camila.rojas@example.cl", "+56911111111"),
        (10588, "22.222.222-2", "Diego", "Fuentes", "1975-11-30", "M", "diego.fuentes@example.cl", "+56922222222"),
        (10604, "33.333.333-3", "Valentina", "Nunez", "1994-07-04", "F", None, "+56933333333"),
        (10711, "44.444.444-4", "Matias", "Soto", "2001-01-22", "M", "matias.soto@example.cl", None),
    ],
    "practitioner": [
        (501, "55.555.555-5", "Dra. Ana Vera", "Cardiologia"),
        (502, "66.666.666-6", "Dr. Luis Pardo", "Medicina General"),
        (503, "77.777.777-7", "Dra. Sofia Lagos", "Dermatologia"),
    ],
    "location": [
        (1, "Box 101", "Torre A", "1"),
        (2, "Box 204", "Torre A", "2"),
        (3, "Box 310", "Torre B", "3"),
    ],
    "appointment_status": [
        (1, "booked"),
        (2, "arrived"),
        (3, "cancelled"),
        (4, "fulfilled"),
    ],
    "appointment_type": [
        (1, "first visit"),
        (2, "follow-up"),
        (3, "teleconsultation"),
    ],
    "appointment": [
        (9001, "2026-11-03T14:30:00", "2026-11-03T15:00:00", 1, 1, 10432, 501, 1, "Chest pain follow-up", 0, "2026-10-20T09:12:00"),
        (9002, "2026-11-04T09:00:00", "2026-11-04T09:30:00", 2, 2, 10588, 502, 2, "Annual check", 0, "2026-10-21T10:00:00"),
        (9003, "2026-11-04T11:00:00", None, 3, 1, 10604, 503, 2, "Skin rash", 1, "2026-10-22T08:30:00"),
        (9004, "2026-11-05T16:00:00", "2026-11-05T16:20:00", 4, 3, 10711, 502, None, "Teleconsult", 0, "2026-10-23T14:45:00"),
    ],
}


def build(db_path: Path | str = config.SOURCE_DB_PATH) -> Path:
    """(Re)create the synthetic source database at ``db_path``."""
    db_path = Path(db_path)
    if db_path.exists():
        db_path.unlink()

    conn = sqlite3.connect(db_path)
    try:
        conn.execute("PRAGMA foreign_keys = ON")
        conn.execute("CREATE TABLE _table_meta (table_name TEXT PRIMARY KEY, comment TEXT)")
        conn.execute(
            "CREATE TABLE _column_meta "
            "(table_name TEXT, column_name TEXT, comment TEXT, "
            "PRIMARY KEY (table_name, column_name))"
        )

        for name, comment, create_sql, col_comments in _SCHEMA:
            conn.execute(create_sql)
            conn.execute("INSERT INTO _table_meta VALUES (?, ?)", (name, comment))
            for col, c in col_comments.items():
                conn.execute("INSERT INTO _column_meta VALUES (?, ?, ?)", (name, col, c))

        for name, rows in _ROWS.items():
            placeholders = ", ".join(["?"] * len(rows[0]))
            conn.executemany(f"INSERT INTO {name} VALUES ({placeholders})", rows)

        conn.commit()
    finally:
        conn.close()
    return db_path


if __name__ == "__main__":
    path = build()
    print(f"Synthetic source database written to {path}")
