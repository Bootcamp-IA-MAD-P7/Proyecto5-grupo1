"""TTS gratis: gTTS (servidor) — sin ElevenLabs/Rachel de pago.

Flutter usa flutter_tts en el cliente como voz principal de demo.
"""

from __future__ import annotations

import base64
import io
import logging

log = logging.getLogger("assistant.tts")


def synthesize(text: str) -> dict | None:
    """Return {audioBase64, contentType, voiceId, provider} or None."""
    clean = (text or "").strip()
    if not clean:
        return None
    if len(clean) > 1200:
        clean = clean[:1200] + "…"

    result = _gtts(clean)
    if result:
        return result

    log.warning("TTS gratis (gTTS) no disponible")
    return None


def _gtts(text: str) -> dict | None:
    try:
        from gtts import gTTS
    except ImportError:
        log.warning("gTTS not installed")
        return None
    try:
        buf = io.BytesIO()
        gTTS(text=text, lang="es").write_to_fp(buf)
        audio = buf.getvalue()
        if not audio:
            return None
        return {
            "audioBase64": base64.b64encode(audio).decode("ascii"),
            "contentType": "audio/mpeg",
            "voiceId": "gtts-es",
            "provider": "gtts",
        }
    except Exception as exc:  # noqa: BLE001
        log.warning("gTTS failed: %s", exc)
        return None
