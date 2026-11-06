"""Step 5 — the review view (demo surface).

Renders the five output blocks of each entity map (mappings, references,
unfilled_required, unmapped_source, ambiguities) as a self-contained HTML file
a reviewer can read and accept/correct. Accept/correct state is kept per-viewer
in the browser (localStorage) — it is a review convenience, not shared state.
"""

from __future__ import annotations

import html
import json
from pathlib import Path

import config


def _normalize(structure_map: dict) -> list[dict]:
    if "maps" in structure_map and isinstance(structure_map["maps"], list):
        return structure_map["maps"]
    # A bare single-entity object (spec section 4 shape).
    if "entity" in structure_map:
        return [structure_map]
    return []


def _esc(v) -> str:
    if v is None:
        return "<span class='muted'>—</span>"
    if isinstance(v, (dict, list)):
        return f"<code>{html.escape(json.dumps(v, ensure_ascii=False))}</code>"
    if isinstance(v, bool):
        return "yes" if v else "no"
    return html.escape(str(v))


def _conf_badge(conf) -> str:
    try:
        c = float(conf)
    except (TypeError, ValueError):
        return _esc(conf)
    cls = "hi" if c >= 0.9 else "mid" if c >= 0.7 else "lo"
    return f"<span class='conf {cls}'>{c:.2f}</span>"


def _review_controls(key: str) -> str:
    return (
        f"<td class='review'>"
        f"<label><input type='checkbox' data-key='{key}:accept'> accept</label>"
        f"<input type='text' class='note' data-key='{key}:note' placeholder='correction / note'>"
        f"</td>"
    )


def _mappings_table(entity: str, mappings: list[dict]) -> str:
    if not mappings:
        return "<p class='muted'>No mappings.</p>"
    rows = []
    for i, m in enumerate(mappings):
        src = m.get("source", {})
        tgt = m.get("target", {})
        src_txt = f"{src.get('table','?')}.{src.get('column','?')}"
        if src.get("via_lookup"):
            src_txt += f" <span class='tag'>via {html.escape(str(src['via_lookup']))}</span>"
        cit = m.get("citation", {})
        rows.append(
            "<tr>"
            f"<td>{src_txt}</td>"
            f"<td>{_esc(tgt.get('element'))}<div class='sub'>{_esc(tgt.get('type'))} · {_esc(tgt.get('profile'))}</div></td>"
            f"<td>{_esc(m.get('transform'))}</td>"
            f"<td>{_esc(m.get('required'))}</td>"
            f"<td>{_esc(m.get('binding'))}"
            + (f"<div class='sub'>{_esc(m.get('terminology_notes'))}</div>" if m.get("terminology_notes") else "")
            + "</td>"
            f"<td>{_conf_badge(m.get('confidence'))}</td>"
            f"<td class='rationale'>{_esc(m.get('rationale'))}"
            f"<div class='cite'>{_esc(cit.get('source'))} · {_esc(cit.get('ref'))}</div></td>"
            + _review_controls(f"{entity}:map:{i}")
            + "</tr>"
        )
    return (
        "<table><thead><tr>"
        "<th>Source</th><th>Target element</th><th>Transform</th><th>Req</th>"
        "<th>Binding</th><th>Conf</th><th>Rationale &amp; citation</th><th>Review</th>"
        "</tr></thead><tbody>" + "".join(rows) + "</tbody></table>"
    )


def _references_table(entity: str, refs: list[dict]) -> str:
    if not refs:
        return "<p class='muted'>No references.</p>"
    rows = []
    for i, r in enumerate(refs):
        tgt = r.get("target", {})
        cit = r.get("citation", {})
        rows.append(
            "<tr>"
            f"<td>{_esc(r.get('source_fk'))}</td>"
            f"<td>{_esc(tgt.get('element'))}<div class='sub'>{_esc(tgt.get('type'))} → {_esc(tgt.get('target_profile'))}</div></td>"
            f"<td>{_conf_badge(r.get('confidence'))}</td>"
            f"<td class='rationale'>{_esc(r.get('rationale'))}"
            f"<div class='cite'>{_esc(cit.get('source'))} · {_esc(cit.get('ref'))}</div></td>"
            + _review_controls(f"{entity}:ref:{i}")
            + "</tr>"
        )
    return (
        "<table><thead><tr>"
        "<th>Source FK</th><th>Target</th><th>Conf</th><th>Rationale &amp; citation</th><th>Review</th>"
        "</tr></thead><tbody>" + "".join(rows) + "</tbody></table>"
    )


def _simple_table(items: list[dict], columns: list[tuple[str, str]]) -> str:
    if not items:
        return "<p class='muted'>None.</p>"
    head = "".join(f"<th>{html.escape(label)}</th>" for _, label in columns)
    rows = []
    for it in items:
        cells = "".join(f"<td>{_esc(it.get(key))}</td>" for key, _ in columns)
        rows.append(f"<tr>{cells}</tr>")
    return f"<table><thead><tr>{head}</tr></thead><tbody>{''.join(rows)}</tbody></table>"


def _entity_section(m: dict) -> str:
    entity = str(m.get("entity", "entity"))
    counts = {
        "mappings": len(m.get("mappings", [])),
        "references": len(m.get("references", [])),
        "unfilled_required": len(m.get("unfilled_required", [])),
        "unmapped_source": len(m.get("unmapped_source", [])),
        "ambiguities": len(m.get("ambiguities", [])),
    }
    pills = " ".join(
        f"<span class='pill'>{v} {html.escape(k.replace('_',' '))}</span>" for k, v in counts.items()
    )
    return f"""
    <section class="entity">
      <h2>{html.escape(entity)} <span class="target">→ {html.escape(str(m.get('target_profile','')))}</span></h2>
      <div class="pills">{pills}</div>

      <h3>Mappings</h3>{_mappings_table(entity, m.get('mappings', []))}
      <h3>References (from declared FKs)</h3>{_references_table(entity, m.get('references', []))}
      <h3>Unfilled required</h3>{_simple_table(m.get('unfilled_required', []), [('element','Element'),('reason','Reason'),('action','Action')])}
      <h3>Unmapped source</h3>{_simple_table(m.get('unmapped_source', []), [('table','Table'),('column','Column'),('reason','Reason')])}
      <h3>Ambiguities (need a human)</h3>{_simple_table(m.get('ambiguities', []), [('location','Location'),('question','Question'),('impact','Impact')])}
    </section>
    """


_CSS = """
:root { --bg:#ffffff; --fg:#1a1d21; --muted:#8a9099; --line:#e4e7eb; --accent:#0b63ce;
        --hi:#1a7f46; --mid:#b5721a; --lo:#b42318; --card:#f7f8fa; }
@media (prefers-color-scheme: dark){ :root:not([data-theme="light"]){
  --bg:#14171a; --fg:#e8eaed; --muted:#9aa0a6; --line:#2a2f35; --accent:#5aa0f2;
  --hi:#4ad77f; --mid:#d79a4a; --lo:#e8766a; --card:#1b1f24; } }
*{box-sizing:border-box} body{margin:0;background:var(--bg);color:var(--fg);
  font:15px/1.5 -apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;padding:0 16px}
header{max-width:1200px;margin:0 auto;padding:28px 0 8px}
h1{font-size:1.6rem;margin:0 0 4px} .meta{color:var(--muted);font-size:.9rem}
main{max-width:1200px;margin:0 auto;padding-bottom:64px}
section.entity{margin:28px 0;border:1px solid var(--line);border-radius:12px;padding:18px;background:var(--card)}
h2{font-size:1.25rem;margin:0 0 6px} h2 .target{color:var(--accent);font-weight:500}
h3{font-size:.95rem;text-transform:uppercase;letter-spacing:.04em;color:var(--muted);
  margin:22px 0 8px;border-bottom:1px solid var(--line);padding-bottom:4px}
.pills{display:flex;gap:8px;flex-wrap:wrap;margin:8px 0}
.pill{background:var(--bg);border:1px solid var(--line);border-radius:999px;padding:3px 10px;font-size:.8rem;color:var(--muted)}
table{width:100%;border-collapse:collapse;font-size:.88rem;margin-bottom:6px}
th,td{text-align:left;padding:8px 10px;border-bottom:1px solid var(--line);vertical-align:top}
th{font-weight:600;color:var(--muted);font-size:.78rem;text-transform:uppercase;letter-spacing:.03em}
td code{background:var(--bg);border:1px solid var(--line);border-radius:5px;padding:1px 5px;font-size:.82em}
.sub{color:var(--muted);font-size:.8rem;margin-top:2px} .cite{color:var(--accent);font-size:.78rem;margin-top:4px}
.rationale{max-width:360px} .muted{color:var(--muted)}
.tag{background:var(--bg);border:1px solid var(--line);border-radius:4px;padding:0 5px;font-size:.75rem;color:var(--muted)}
.conf{font-weight:600;border-radius:5px;padding:1px 7px;font-size:.82rem}
.conf.hi{color:var(--hi)} .conf.mid{color:var(--mid)} .conf.lo{color:var(--lo)}
td.review{white-space:nowrap} td.review label{display:block;font-size:.8rem;margin-bottom:4px}
td.review .note{width:150px;font-size:.8rem;padding:3px 5px;border:1px solid var(--line);border-radius:5px;background:var(--bg);color:var(--fg)}
"""

_JS = """
<script>
(function(){
  const KEY='structure-map-review';
  let state={};
  try{ state=JSON.parse(localStorage.getItem(KEY)||'{}'); }catch(e){}
  function save(){ try{ localStorage.setItem(KEY, JSON.stringify(state)); }catch(e){} }
  document.querySelectorAll('[data-key]').forEach(el=>{
    const k=el.getAttribute('data-key');
    if(el.type==='checkbox'){ el.checked=!!state[k]; el.addEventListener('change',()=>{state[k]=el.checked;save();}); }
    else { el.value=state[k]||''; el.addEventListener('input',()=>{state[k]=el.value;save();}); }
  });
})();
</script>
"""


def render(structure_map: dict, title: str = "Structure Map — Review") -> str:
    maps = _normalize(structure_map)
    generated = structure_map.get("generated_at", "")
    body = "".join(_entity_section(m) for m in maps) or "<p class='muted'>No entity maps.</p>"
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title><style>{_CSS}</style></head>
<body>
<header><h1>{html.escape(title)}</h1>
<div class="meta">Generated {html.escape(str(generated))} · {len(maps)} entit{'y' if len(maps)==1 else 'ies'} ·
confidence <span class="conf hi">≥0.90</span> <span class="conf mid">0.70–0.89</span> <span class="conf lo">&lt;0.70</span></div>
</header>
<main>{body}</main>
{_JS}
</body></html>"""


def render_to_file(
    structure_map: dict | str | Path = config.STRUCTURE_MAP_PATH,
    out_path: Path | str = config.REVIEW_HTML_PATH,
) -> Path:
    if isinstance(structure_map, (str, Path)):
        structure_map = json.loads(Path(structure_map).read_text(encoding="utf-8"))
    out_path = Path(out_path)
    out_path.write_text(render(structure_map), encoding="utf-8")
    return out_path


if __name__ == "__main__":
    path = render_to_file()
    print(f"review view written to {path}")
