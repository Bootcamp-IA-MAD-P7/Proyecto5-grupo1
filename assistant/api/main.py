"""
SentiLife Assistant Agent — FastAPI (RF-46, RF-47).

Internal service called only by the Java backend.
Endpoints:
  GET  /health
  POST /assistant/chat
  POST /assistant/transcribe
  POST /assistant/speak
"""

from __future__ import annotations

import logging

from fastapi import FastAPI, File, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from api import config
from api.agent import GroqUnavailable, chat, transcribe
from api.rag import INDEX
from api.tts import synthesize

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("assistant")

app = FastAPI(
    title="SentiLife Assistant Agent",
    description="Groq LLM + Whisper + RAG + tools. Internal only.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    role: str = Field(default="MONITORED")
    locale: str = Field(default="es")
    conversationId: str | None = None
    tts: bool = False


class SpeakRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4000)


@app.on_event("startup")
def _startup() -> None:
    n = INDEX.build()
    log.info("Assistant ready — RAG chunks=%s groq=%s tts=gtts",
             n, bool(config.GROQ_API_KEY))


@app.get("/health")
def health() -> dict:
    return {
        "status": "healthy",
        "service": "assistant",
        "groqConfigured": bool(config.GROQ_API_KEY),
        "ttsProvider": "gtts",
        "ragChunks": len(INDEX.chunks),
    }


@app.post("/assistant/chat")
def assistant_chat(
    body: ChatRequest,
    authorization: str | None = Header(default=None),
) -> dict:
    if not config.GROQ_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="GROQ_API_KEY no configurada. El asistente no está disponible.",
        )
    try:
        return chat(
            message=body.message,
            role=body.role,
            locale=body.locale,
            authorization=authorization,
            conversation_id=body.conversationId,
            tts=body.tts,
        )
    except GroqUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        log.exception("chat failed")
        raise HTTPException(status_code=502, detail=f"Error del agente: {exc}") from exc


@app.post("/assistant/transcribe")
async def assistant_transcribe(audio: UploadFile = File(...)) -> dict:
    if not config.GROQ_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="GROQ_API_KEY no configurada. La transcripción no está disponible.",
        )
    data = await audio.read()
    if not data:
        raise HTTPException(status_code=400, detail="Audio vacío")
    if len(data) > config.MAX_AUDIO_BYTES:
        raise HTTPException(status_code=400, detail="Audio demasiado grande (máx ~5 MB / 30 s)")
    filename = audio.filename or "audio.m4a"
    try:
        return transcribe(data, filename=filename)
    except GroqUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        log.exception("transcribe failed")
        raise HTTPException(status_code=502, detail=f"Error Whisper: {exc}") from exc


@app.post("/assistant/speak")
def assistant_speak(body: SpeakRequest) -> dict:
    result = synthesize(body.text)
    if result is None:
        raise HTTPException(
            status_code=503,
            detail="TTS no disponible (ElevenLabs/Edge). Revisa claves o red.",
        )
    return result
