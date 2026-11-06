# Implementation guide store — input files

Drop the three CSVs of the **Bupa Chile Core Implementation Guide**
(`fhir.bupa.core` 4.6.0, FHIR R4) here, then run:

```bash
python main.py load-guide
```

Expected file names (configurable in [`config.py`](../config.py) → `GUIDE_CSVS`):

| File | Loaded as table | Backs the tool |
| --- | --- | --- |
| `campos_perfiles.csv` | `campos` | `consultar_campo`, `listar_perfiles_por_dominio` |
| `modelos_logicos.csv` | `modelos` | `ver_modelo_logico` |
| `terminologias.csv` | `terminologias` | `buscar_binding` |

## Column resolution

The loader does **not** require specific headers. It loads each CSV verbatim,
then resolves the *logical* columns the tools need against whatever headers your
CSVs actually have (case- and accent-insensitive, Spanish or English). After
loading, it prints a warning for any logical column it could not resolve.

Logical columns the tools expect:

- **campos** → `profile`, `element`, `min`, `max`, `type`, `binding`,
  `binding_strength`, `fixed`, `must_support`, `logical_model`
- **modelos** → `logical_model`, `field`, `definition`, `type`
- **terminologias** → `valueset`, `code`, `display`, `system`

## Overriding the mapping

If a column does not resolve automatically (or resolves wrongly), copy
[`columns.example.json`](columns.example.json) to `columns.json` and set the
real header name for each logical column you need. Overrides win over
auto-resolution.

## Narrative pages (optional)

Put any `.md`/`.txt` narrative pages of the guide under `guide/narrative/`.
They are indexed by section heading and made searchable through `buscar_en_guia`.
Without them, `buscar_en_guia` falls back to searching element names and
definitions in the CSVs.

> These files are listed in `.gitignore` — they are treated as confidential and
> are not committed.
