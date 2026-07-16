"""Environment configuration for the assistant agent."""

from __future__ import annotations

import os
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]


def _load_dotenv_file() -> None:
    """Load repo-root .env into os.environ if keys are missing (local/dev)."""
    env_path = _REPO_ROOT / ".env"
    if not env_path.is_file():
        return
    try:
        for raw in env_path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip().strip("'").strip('"')
            if key and key not in os.environ:
                os.environ[key] = value
    except OSError:
        pass


_load_dotenv_file()


def _env(name: str, default: str = "") -> str:
    return os.environ.get(name, default).strip()


GROQ_API_KEY = _env("GROQ_API_KEY")
GROQ_CHAT_MODEL = _env("GROQ_CHAT_MODEL", "llama-3.3-70b-versatile")
GROQ_WHISPER_MODEL = _env("GROQ_WHISPER_MODEL", "whisper-large-v3")

JAVA_URL = _env("JAVA_URL", "http://backend:8080").rstrip("/")
INFERENCE_URL = _env("INFERENCE_URL", "http://api:8000").rstrip("/")

CORPUS_ROOT = Path(_env("CORPUS_ROOT", "/corpus"))
# Local fallback when running outside Docker
if not CORPUS_ROOT.exists():
    CORPUS_ROOT = _REPO_ROOT

MAX_TOOL_ROUNDS = int(_env("ASSISTANT_MAX_TOOL_ROUNDS", "4"))
MAX_AUDIO_BYTES = int(_env("ASSISTANT_MAX_AUDIO_BYTES", str(5 * 1024 * 1024)))


def require_groq_key() -> str:
    if not GROQ_API_KEY:
        raise RuntimeError(
            "GROQ_API_KEY no configurada. El asistente no puede responder sin la clave."
        )
    return GROQ_API_KEY
