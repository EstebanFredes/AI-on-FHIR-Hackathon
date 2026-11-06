# Structure Map Agent — Clinical Interoperability Copilot

Given the **metadata of a source SQL database** and a **FHIR implementation
guide** (Bupa Chile Core, `fhir.bupa.core` 4.6.0, FHIR R4), the agent proposes a
**structure map**: for each source column, which FHIR element it should map to,
with what type, terminology and transformation — **citing the exact source for
every decision**.

See [`docs/context.md`](docs/context.md) for the full design. This repository is
the implementation of its section 8 build order.

## Responsibilities (spec §1)

| The application does (deterministic) | The agent does (judgment) |
| --- | --- |
| Connect to the DB, read the catalog | Understand what each source column means |
| Extract tables, columns, types, nullability | Match each column to a FHIR element |
| Extract declared PK / FK | Turn FKs into FHIR references |
| Extract lookup contents + value samples | Align lookup values to FHIR value sets |
| Produce `source_metadata.json` | Produce `structure_map.json` |

## Architecture

```
synthetic source.db ──► extractor ──► source_metadata.json ─┐
                                                            ├──► Agent ──► structure_map.json ──► review.html
guide CSVs ──► guide.db ──► Phase B tools ──────────────────┘
```

- **`src/source_db/`** — step 1: builds a synthetic SQLite source (appointment,
  patient, practitioner, location + status/type lookups) with declared PK/FK.
- **`src/extractor/`** — step 2: reads the catalog → `source_metadata.json`
  (types, nullability, FKs, value samples, lookup contents).
- **`src/guide/`** — step 3: loads the three guide CSVs into SQLite and exposes
  the five Phase B tools (`consultar_campo`, `ver_modelo_logico`,
  `buscar_binding`, `buscar_en_guia`, `listar_perfiles_por_dominio`).
- **`src/agent/`** — step 4: the Claude tool-use loop (Phase A→B→C) →
  `structure_map.json`.
- **`src/review/`** — step 5: renders the five output blocks to `review.html`.

## Setup

> **Python version:** use a **stable Python 3.11–3.13** for the agent step. The
> Anthropic SDK depends on `jiter`, whose compiled wheel does not load on
> Python 3.15 alpha (`ImportError: DLL load failed while importing jiter`).
> Steps 1–3 and 5 run on any Python 3.10+; only step 4 needs the SDK.

```bash
py -3.12 -m venv .venv && .venv\Scripts\activate   # Windows (PowerShell)
pip install -r requirements.txt
copy .env.example .env    # then set ANTHROPIC_API_KEY (or use `ant auth login`)
```

Put the three Implementation Guide CSVs in [`guide/`](guide/) — see
[`guide/README.md`](guide/README.md) for the expected names and the
schema-tolerant column resolution.

## Run

```bash
python main.py build-db      # 1. synthetic source DB (fixture)
python main.py extract       # 2. source_metadata.json
python main.py load-guide    # 3. guide store (needs the CSVs)
python main.py agent         # 4. structure_map.json  (needs ANTHROPIC_API_KEY)
python main.py review        # 5. review.html
# or everything at once:
python main.py all
```

All artifacts are written to [`data/`](data/). Open `data/review.html` in a
browser to accept/correct each proposed mapping.

## Notes

- Default model is `claude-opus-5-5` (override with `ANTHROPIC_MODEL`).
- Steps 1–3 and 5 run offline; only step 4 calls the API.
- The output is a readable JSON map, **not** a formal FHIR `StructureMap`
  resource — that compile step is open item 1 in the spec.
- Synthetic data only; the agent never invents codes or columns to fill a gap.
