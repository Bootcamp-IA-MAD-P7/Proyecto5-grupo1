#!/usr/bin/env bash
# T6.8 / T6.INT — Smoke asistente IA:
#   IT_ADMIN: RAG + tool retrain
#   CAREGIVER: pregunta por alertas
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() { echo "✗ $1" >&2; exit 1; }
ok()   { echo "✓ $1"; }

JAVA_PORT="${JAVA_PORT:-8080}"
ASSISTANT_PORT="${ASSISTANT_PORT:-8001}"
export SMOKE_JAVA_URL="${SMOKE_JAVA_URL:-http://localhost:${JAVA_PORT}}"
ASSISTANT_URL="${SMOKE_ASSISTANT_URL:-http://localhost:${ASSISTANT_PORT}}"

echo "=== T6.8 / T6.INT — Smoke asistente IA ==="
echo "→ Java API:      ${SMOKE_JAVA_URL}"
echo "→ Assistant API: ${ASSISTANT_URL}"

if [[ "${SMOKE_SKIP_VERIFY:-0}" != "1" ]]; then
  bash scripts/verify-local.sh >/dev/null || fail "Stack no sano — ejecuta: make up"
else
  curl -sf --max-time 10 "${SMOKE_JAVA_URL}/actuator/health" | grep -q '"status":"UP"' \
    || fail "Java health not UP"
fi
ok "Java health UP"

curl -sf --max-time 10 "${ASSISTANT_URL}/health" | grep -q '"status":"healthy"' \
  || fail "Assistant health not healthy"
ok "Assistant health OK"

GROQ_OK="$(curl -sf "${ASSISTANT_URL}/health" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("groqConfigured"))')"
[[ "$GROQ_OK" == "True" ]] || fail "GROQ_API_KEY no configurada en el servicio assistant"
ok "GROQ_API_KEY presente"

python3 - <<'PY'
import json, os, sys, time, urllib.request, urllib.error

JAVA = os.environ["SMOKE_JAVA_URL"]
ts = int(time.time())
admin_email = "admin@sentilife.com"
admin_pw = "Admin1234!"
cg_email = f"cg-asst-{ts}@sentilife.test"
pw = "SmokeTest1!"

def http(method, base, path, data=None, token=None, timeout=90):
    headers = {"Content-Type": "application/json"}
    body = json.dumps(data).encode() if data is not None else None
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(base + path, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            raw = r.read()
            return r.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            payload = json.loads(raw) if raw else {}
        except Exception:
            payload = {"message": raw.decode("utf-8", errors="replace")}
        return e.code, payload

# ── IT_ADMIN ──────────────────────────────────────────────────────
status, login = http("POST", JAVA, "/api/v1/auth/login", {
    "email": admin_email,
    "password": admin_pw,
})
if status != 200:
    print(f"FAIL login IT_ADMIN HTTP {status}: {login}", file=sys.stderr)
    sys.exit(1)
admin_token = login["accessToken"]

status, chat = http("POST", JAVA, "/api/v1/assistant/chat", {
    "message": "¿Qué es SL-14 y el contrato de ventana IMU en SentiLife?",
    "locale": "es",
    "tts": False,
}, token=admin_token)
if status != 200 or len((chat.get("reply") or "")) < 20:
    print(f"FAIL chat RAG HTTP {status}: {chat}", file=sys.stderr)
    sys.exit(1)
print("✓ IT_ADMIN RAG OK", "sources=", chat.get("sources"), "tools=", chat.get("toolsUsed"))

status, chat2 = http("POST", JAVA, "/api/v1/assistant/chat", {
    "message": "¿Puedo lanzar un reentrenamiento ahora? Usa prerequisites reales.",
    "locale": "es",
    "tts": False,
}, token=admin_token)
if status != 200:
    print(f"FAIL chat retrain HTTP {status}: {chat2}", file=sys.stderr)
    sys.exit(1)
tools = chat2.get("toolsUsed") or []
if "get_retrain_prerequisites" not in tools and "get_retrain_status" not in tools:
    print(f"⚠ retrain tools soft: {tools}", file=sys.stderr)
else:
    print("✓ IT_ADMIN retrain tool OK", tools)
print("  →", (chat2.get("reply") or "")[:220])

# ── CAREGIVER ─────────────────────────────────────────────────────
status, reg = http("POST", JAVA, "/api/v1/auth/register", {
    "email": cg_email,
    "password": pw,
    "fullName": "Caregiver Assistant Smoke",
    "role": "CAREGIVER",
    "locale": "es",
})
if status not in (200, 201):
    print(f"FAIL register CAREGIVER HTTP {status}: {reg}", file=sys.stderr)
    sys.exit(1)
status, cg_login = http("POST", JAVA, "/api/v1/auth/login", {
    "email": cg_email,
    "password": pw,
})
if status != 200:
    print(f"FAIL login CAREGIVER HTTP {status}: {cg_login}", file=sys.stderr)
    sys.exit(1)
cg_token = cg_login["accessToken"]

status, chat3 = http("POST", JAVA, "/api/v1/assistant/chat", {
    "message": "¿Hay alertas recientes de caídas para mis personas monitorizadas?",
    "locale": "es",
    "tts": False,
}, token=cg_token)
if status != 200 or len((chat3.get("reply") or "")) < 10:
    print(f"FAIL caregiver alerts chat HTTP {status}: {chat3}", file=sys.stderr)
    sys.exit(1)
cg_tools = chat3.get("toolsUsed") or []
print("✓ CAREGIVER alerts chat OK", "tools=", cg_tools)
print("  →", (chat3.get("reply") or "")[:220])

# Voz opcional: speak no debe tumbar el smoke (gTTS best-effort)
status, speak = http("POST", JAVA, "/api/v1/assistant/speak", {
    "text": "Asistente SentiLife listo para la demo.",
}, token=admin_token)
if status == 200 and speak.get("audioBase64"):
    print("✓ TTS gTTS OK", "provider=", speak.get("provider") or speak.get("voiceId"))
else:
    print(f"⚠ TTS opcional no disponible HTTP {status} (flutter_tts cubre la demo)")

print("✓ T6.8 + T6.INT PASS")
PY

ok "Smoke asistente (IT_ADMIN + CAREGIVER) completado"
