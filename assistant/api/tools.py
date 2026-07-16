"""Agent tools: RAG + HTTP delegation to Java/inference (RBAC by role)."""

from __future__ import annotations

import json
import logging
from typing import Any, Callable

import httpx

from api import config
from api.rag import INDEX

log = logging.getLogger("assistant.tools")

TOOLS_BY_ROLE: dict[str, set[str]] = {
    "IT_ADMIN": {
        "search_docs",
        "get_retrain_prerequisites",
        "get_retrain_status",
        "get_drift_snapshot",
        "get_model_registry",
        "get_recent_alerts",
    },
    "CAREGIVER": {
        "search_docs",
        "get_recent_alerts",
    },
    "MONITORED": {
        "search_docs",
    },
}

GROQ_TOOL_SCHEMAS: list[dict[str, Any]] = [
    {
        "type": "function",
        "function": {
            "name": "search_docs",
            "description": "Busca en la documentación del proyecto (docs, contracts, README, spec).",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Consulta en lenguaje natural o palabras clave",
                    }
                },
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_retrain_prerequisites",
            "description": "Elegibilidad de reentrenamiento (feedback etiquetado vs mínimo).",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_retrain_status",
            "description": "Estado del último job de reentrenamiento.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_drift_snapshot",
            "description": "Snapshot de drift de features (PSI) del servicio de inferencia.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_model_registry",
            "description": "Lista versiones del model registry (vía Java admin).",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_recent_alerts",
            "description": "Alertas recientes del cuidador autenticado (o globales si IT_ADMIN).",
            "parameters": {
                "type": "object",
                "properties": {
                    "status": {
                        "type": "string",
                        "description": "Filtro opcional PENDING|CONFIRMED|DISMISSED",
                    }
                },
            },
        },
    },
]


def schemas_for_role(role: str) -> list[dict[str, Any]]:
    allowed = TOOLS_BY_ROLE.get(role.upper(), TOOLS_BY_ROLE["MONITORED"])
    return [t for t in GROQ_TOOL_SCHEMAS if t["function"]["name"] in allowed]


class ToolContext:
    def __init__(self, role: str, authorization: str | None) -> None:
        self.role = role.upper()
        self.authorization = authorization


def _auth_headers(ctx: ToolContext) -> dict[str, str]:
    headers = {"Accept": "application/json"}
    if ctx.authorization:
        headers["Authorization"] = ctx.authorization
    return headers


def _get_json(url: str, headers: dict[str, str] | None = None) -> Any:
    with httpx.Client(timeout=20.0) as client:
        resp = client.get(url, headers=headers or {})
        resp.raise_for_status()
        return resp.json()


def search_docs(query: str, **_: Any) -> dict[str, Any]:
    hits = INDEX.search(query, k=4)
    return {"results": hits, "count": len(hits)}


def get_retrain_prerequisites(ctx: ToolContext, **_: Any) -> Any:
    return _get_json(
        f"{config.JAVA_URL}/api/v1/admin/retrain/prerequisites",
        _auth_headers(ctx),
    )


def get_retrain_status(ctx: ToolContext, **_: Any) -> Any:
    return _get_json(
        f"{config.JAVA_URL}/api/v1/admin/retrain/status",
        _auth_headers(ctx),
    )


def get_drift_snapshot(ctx: ToolContext, **_: Any) -> Any:
    return _get_json(f"{config.INFERENCE_URL}/drift")


def get_model_registry(ctx: ToolContext, **_: Any) -> Any:
    return _get_json(
        f"{config.JAVA_URL}/api/v1/admin/models",
        _auth_headers(ctx),
    )


def get_recent_alerts(ctx: ToolContext, status: str | None = None, **_: Any) -> Any:
    if ctx.role == "IT_ADMIN":
        # Admin history endpoint (global)
        url = f"{config.JAVA_URL}/api/v1/admin/history?size=10"
        return _get_json(url, _auth_headers(ctx))
    url = f"{config.JAVA_URL}/api/v1/alerts?size=10"
    if status:
        url += f"&status={status}"
    return _get_json(url, _auth_headers(ctx))


_DISPATCH: dict[str, Callable[..., Any]] = {
    "search_docs": lambda ctx, **kwargs: search_docs(**kwargs),
    "get_retrain_prerequisites": get_retrain_prerequisites,
    "get_retrain_status": get_retrain_status,
    "get_drift_snapshot": get_drift_snapshot,
    "get_model_registry": get_model_registry,
    "get_recent_alerts": get_recent_alerts,
}


def execute_tool(name: str, arguments: dict[str, Any], ctx: ToolContext) -> str:
    allowed = TOOLS_BY_ROLE.get(ctx.role, TOOLS_BY_ROLE["MONITORED"])
    if name not in allowed:
        return json.dumps(
            {"error": "FORBIDDEN", "message": f"Tool '{name}' no permitida para rol {ctx.role}"},
            ensure_ascii=False,
        )
    fn = _DISPATCH.get(name)
    if fn is None:
        return json.dumps({"error": f"Unknown tool: {name}"})
    try:
        result = fn(ctx=ctx, **(arguments or {}))
        return json.dumps(result, ensure_ascii=False, default=str)
    except httpx.HTTPStatusError as exc:
        log.warning("tool %s HTTP %s", name, exc.response.status_code)
        return json.dumps(
            {
                "error": "HTTP_ERROR",
                "status": exc.response.status_code,
                "body": exc.response.text[:500],
            },
            ensure_ascii=False,
        )
    except Exception as exc:  # noqa: BLE001 — surface to LLM
        log.exception("tool %s failed", name)
        return json.dumps({"error": str(exc)}, ensure_ascii=False)
