"""Phase B tools (spec section 6) — the agent's only window onto the guide.

Each tool is a thin, deterministic wrapper over a GuideStore query. The agent
calls these for every field fact; it must not recall field facts from memory
(spec section 7.2). Tool names and semantics follow the table in section 6.
"""

from __future__ import annotations

import json

from src.guide.store import GuideStore

# Anthropic tool definitions (strict schemas so arguments validate exactly).
TOOL_DEFINITIONS = [
    {
        "name": "consultar_campo",
        "description": (
            "Query the implementation guide's field table (campos_perfiles). "
            "Filter by profile and/or element, or by flags (required, "
            "must_support, has_binding). Returns rows with min/max cardinality, "
            "FHIR type, binding value set, fixed value and logical model. Use "
            "this to find the FHIR element a source column should map to and to "
            "read its facts. Never state a field fact you did not get here."
        ),
        "strict": True,
        "input_schema": {
            "type": "object",
            "properties": {
                "profile": {"type": ["string", "null"], "description": "Profile id or substring, e.g. 'appointment-bupa'."},
                "element": {"type": ["string", "null"], "description": "FHIR element path or substring, e.g. 'Appointment.start'."},
                "required": {"type": ["boolean", "null"], "description": "If true, only elements with min>=1."},
                "must_support": {"type": ["boolean", "null"], "description": "Filter by mustSupport."},
                "has_binding": {"type": ["boolean", "null"], "description": "If true, only elements with a terminology binding."},
            },
            "required": ["profile", "element", "required", "must_support", "has_binding"],
            "additionalProperties": False,
        },
    },
    {
        "name": "ver_modelo_logico",
        "description": (
            "Read business-language field definitions from the logical models "
            "(modelos_logicos). Use it to understand what a guide field means in "
            "plain terms when matching a source column by concept."
        ),
        "strict": True,
        "input_schema": {
            "type": "object",
            "properties": {
                "logical_model": {"type": ["string", "null"], "description": "Logical model name or substring."},
                "field": {"type": ["string", "null"], "description": "Field name or substring."},
            },
            "required": ["logical_model", "field"],
            "additionalProperties": False,
        },
    },
    {
        "name": "buscar_binding",
        "description": (
            "Look up the codes and displays of a terminology value set "
            "(terminologias). Use it for code columns: align the source lookup "
            "labels against the FHIR value set and report mismatches."
        ),
        "strict": True,
        "input_schema": {
            "type": "object",
            "properties": {
                "valueset": {"type": "string", "description": "Value set name or substring, e.g. 'appointment-status'."},
            },
            "required": ["valueset"],
            "additionalProperties": False,
        },
    },
    {
        "name": "buscar_en_guia",
        "description": (
            "Free-text search across the guide's narrative pages and field "
            "names. Returns matching sections with their section path. Use it "
            "when you don't yet know which profile or element is relevant."
        ),
        "strict": True,
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Natural-language query."},
            },
            "required": ["query"],
            "additionalProperties": False,
        },
    },
    {
        "name": "listar_perfiles_por_dominio",
        "description": (
            "List candidate FHIR profiles in the guide, optionally filtered by a "
            "domain or resource substring (e.g. 'appointment', 'patient'). Use "
            "it to pick candidate target profiles for a source entity."
        ),
        "strict": True,
        "input_schema": {
            "type": "object",
            "properties": {
                "domain": {"type": ["string", "null"], "description": "Domain/resource substring, or null for all."},
            },
            "required": ["domain"],
            "additionalProperties": False,
        },
    },
]


class GuideTools:
    """Dispatches tool calls to the GuideStore and serialises results to JSON."""

    def __init__(self, store: GuideStore | None = None):
        self.store = store or GuideStore()

    def dispatch(self, name: str, args: dict) -> str:
        try:
            result = self._call(name, args or {})
            return json.dumps({"rows": result, "count": len(result)}, ensure_ascii=False)
        except Exception as exc:  # surfaced to the model as an error tool_result
            return json.dumps({"error": f"{type(exc).__name__}: {exc}"}, ensure_ascii=False)

    def _call(self, name: str, args: dict):
        if name == "consultar_campo":
            return self.store.consultar_campo(
                profile=args.get("profile"),
                element=args.get("element"),
                required=args.get("required"),
                must_support=args.get("must_support"),
                has_binding=args.get("has_binding"),
            )
        if name == "ver_modelo_logico":
            return self.store.ver_modelo_logico(
                logical_model=args.get("logical_model"), field=args.get("field")
            )
        if name == "buscar_binding":
            return self.store.buscar_binding(valueset=args["valueset"])
        if name == "buscar_en_guia":
            return self.store.buscar_en_guia(query=args["query"])
        if name == "listar_perfiles_por_dominio":
            return self.store.listar_perfiles_por_dominio(domain=args.get("domain"))
        raise ValueError(f"unknown tool: {name}")
