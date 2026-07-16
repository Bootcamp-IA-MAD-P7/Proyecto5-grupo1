"""Groq chat agent with tool loop (RF-46)."""

from __future__ import annotations

import json
import logging
from typing import Any

from groq import BadRequestError, Groq

from api import config
from api.prompts import system_prompt
from api.rag import INDEX
from api.tools import ToolContext, execute_tool, schemas_for_role
from api.tts import synthesize

log = logging.getLogger("assistant.agent")


class GroqUnavailable(RuntimeError):
    pass


def chat(
    *,
    message: str,
    role: str,
    locale: str = "es",
    authorization: str | None = None,
    conversation_id: str | None = None,
    tts: bool = False,
) -> dict[str, Any]:
    try:
        api_key = config.require_groq_key()
    except RuntimeError as exc:
        raise GroqUnavailable(str(exc)) from exc

    client = Groq(api_key=api_key)
    tools = schemas_for_role(role)
    ctx = ToolContext(role=role, authorization=authorization)

    tools_used: list[str] = []
    sources: list[str] = []

    # Always prefetch RAG so docs work even if Groq tool-calling misformats.
    rag_hits = INDEX.search(message, k=4)
    for hit in rag_hits:
        src = hit.get("source")
        if src and src not in sources:
            sources.append(src)
    if rag_hits:
        tools_used.append("search_docs")

    rag_block = _format_rag(rag_hits)
    prefetch = _prefetch_tools(message, ctx, tools_used)
    prefetch_block = _format_prefetch(prefetch)

    sys = system_prompt(role, locale)
    if rag_block:
        sys += f"\n\nDocumentación relevante (RAG):\n{rag_block}"
    if prefetch_block:
        sys += f"\n\nDatos del sistema (tools):\n{prefetch_block}"
    sys += (
        "\n\nSi usas tools, llama solo funciones del schema JSON de OpenAI "
        "(no uses XML <function=...>). Si ya tienes datos arriba, responde directo."
    )

    messages: list[dict[str, Any]] = [
        {"role": "system", "content": sys},
        {"role": "user", "content": message},
    ]

    reply = _run_completion(client, messages, tools, ctx, tools_used, sources)
    if not reply:
        reply = (
            "No pude generar una respuesta completa. Prueba a reformular la pregunta "
            "o consulta la ayuda del perfil."
        )

    out: dict[str, Any] = {
        "reply": reply,
        "sources": sources,
        "toolsUsed": _dedupe(tools_used),
        "conversationId": conversation_id,
    }
    if tts:
        audio = synthesize(reply)
        if audio:
            out.update(audio)
    return out


def _run_completion(
    client: Groq,
    messages: list[dict[str, Any]],
    tools: list[dict[str, Any]],
    ctx: ToolContext,
    tools_used: list[str],
    sources: list[str],
) -> str:
    # First try with tools; on Groq tool_use_failed, synthesize without tools.
    try:
        return _tool_loop(client, messages, tools, ctx, tools_used, sources)
    except BadRequestError as exc:
        if "tool_use_failed" not in str(exc):
            raise
        log.warning("Groq tool_use_failed — retry without tools")
        return _tool_loop(client, messages, [], ctx, tools_used, sources)


def _tool_loop(
    client: Groq,
    messages: list[dict[str, Any]],
    tools: list[dict[str, Any]],
    ctx: ToolContext,
    tools_used: list[str],
    sources: list[str],
) -> str:
    working = list(messages)
    for _ in range(config.MAX_TOOL_ROUNDS):
        kwargs: dict[str, Any] = {
            "model": config.GROQ_CHAT_MODEL,
            "messages": working,
            "temperature": 0.2,
            "max_tokens": 1024,
        }
        if tools:
            kwargs["tools"] = tools
            kwargs["tool_choice"] = "auto"

        completion = client.chat.completions.create(**kwargs)
        msg = completion.choices[0].message

        if msg.tool_calls:
            working.append(
                {
                    "role": "assistant",
                    "content": msg.content or "",
                    "tool_calls": [
                        {
                            "id": tc.id,
                            "type": "function",
                            "function": {
                                "name": tc.function.name,
                                "arguments": tc.function.arguments or "{}",
                            },
                        }
                        for tc in msg.tool_calls
                    ],
                }
            )
            for tc in msg.tool_calls:
                name = tc.function.name
                try:
                    args = json.loads(tc.function.arguments or "{}")
                except json.JSONDecodeError:
                    args = {}
                tools_used.append(name)
                result = execute_tool(name, args, ctx)
                if name == "search_docs":
                    try:
                        payload = json.loads(result)
                        for hit in payload.get("results", []):
                            src = hit.get("source")
                            if src and src not in sources:
                                sources.append(src)
                    except json.JSONDecodeError:
                        pass
                working.append(
                    {
                        "role": "tool",
                        "tool_call_id": tc.id,
                        "name": name,
                        "content": result,
                    }
                )
            continue

        return (msg.content or "").strip()
    return ""


def _prefetch_tools(message: str, ctx: ToolContext, tools_used: list[str]) -> dict[str, Any]:
    text = message.lower()
    out: dict[str, Any] = {}

    def want(*keys: str) -> bool:
        return any(k in text for k in keys)

    if want("retrain", "reentrenamiento", "reentren", "prerequis", "prerequisite", "feedback"):
        if "get_retrain_prerequisites" in _allowed(ctx):
            out["get_retrain_prerequisites"] = json.loads(
                execute_tool("get_retrain_prerequisites", {}, ctx)
            )
            tools_used.append("get_retrain_prerequisites")
        if "get_retrain_status" in _allowed(ctx) and want("estado", "status", "job", "fase"):
            out["get_retrain_status"] = json.loads(execute_tool("get_retrain_status", {}, ctx))
            tools_used.append("get_retrain_status")

    if want("drift", "psi"):
        if "get_drift_snapshot" in _allowed(ctx):
            out["get_drift_snapshot"] = json.loads(execute_tool("get_drift_snapshot", {}, ctx))
            tools_used.append("get_drift_snapshot")

    if want("registry", "modelo", "model", "versión", "version"):
        if "get_model_registry" in _allowed(ctx):
            out["get_model_registry"] = json.loads(execute_tool("get_model_registry", {}, ctx))
            tools_used.append("get_model_registry")

    if want("alerta", "alert", "caída", "caida", "pending"):
        if "get_recent_alerts" in _allowed(ctx):
            out["get_recent_alerts"] = json.loads(execute_tool("get_recent_alerts", {}, ctx))
            tools_used.append("get_recent_alerts")

    return out


def _allowed(ctx: ToolContext) -> set[str]:
    from api.tools import TOOLS_BY_ROLE

    return TOOLS_BY_ROLE.get(ctx.role, TOOLS_BY_ROLE["MONITORED"])


def _format_rag(hits: list[dict]) -> str:
    if not hits:
        return ""
    parts = []
    for h in hits:
        parts.append(f"- [{h.get('source')}]\n{h.get('snippet', '')[:450]}")
    return "\n\n".join(parts)


def _format_prefetch(data: dict[str, Any]) -> str:
    if not data:
        return ""
    return json.dumps(data, ensure_ascii=False, default=str)[:6000]


def _dedupe(items: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for item in items:
        if item in seen:
            continue
        seen.add(item)
        out.append(item)
    return out


def transcribe(audio_bytes: bytes, filename: str = "audio.m4a") -> dict[str, Any]:
    try:
        api_key = config.require_groq_key()
    except RuntimeError as exc:
        raise GroqUnavailable(str(exc)) from exc

    client = Groq(api_key=api_key)
    transcription = client.audio.transcriptions.create(
        file=(filename, audio_bytes),
        model=config.GROQ_WHISPER_MODEL,
        response_format="verbose_json",
        language="es",
    )
    text = getattr(transcription, "text", None) or str(transcription)
    language = getattr(transcription, "language", None) or "es"
    return {"text": text.strip(), "language": language}
