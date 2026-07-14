#!/usr/bin/env bash
# T1.INT / SL-25 — Smoke telemetría real: app path simulado vía API
# Flujo: CAREGIVER registra persona → MONITORED empareja → consentimiento →
#        POST /telemetry/windows → Java → FastAPI /predict (modelo real)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() { echo "✗ $1" >&2; exit 1; }
ok()   { echo "✓ $1"; }

JAVA_PORT="${JAVA_PORT:-8080}"
JAVA_URL="http://localhost:${JAVA_PORT}"

echo "=== T1.INT — Smoke telemetría E2E (SL-25) ==="

# 1. Stack sano
bash scripts/verify-local.sh >/dev/null || fail "Stack no sano — ejecuta: make up"

# 2. Ejecutar flujo completo y medir latencia
export SMOKE_JAVA_URL="$JAVA_URL"
RESULT="$(python3 - <<'PY'
import json, os, time, urllib.request
from datetime import datetime, timezone, timedelta

JAVA = os.environ["SMOKE_JAVA_URL"]
N = 125
ts = int(time.time())
cg_email = f"cg-smoke-{ts}@sentilife.test"
mon_email = f"mon-smoke-{ts}@sentilife.test"
pw = "SmokeTest1!"

def http(method, path, data=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(JAVA + path, data=body, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())

def build_samples(spike=False):
    samples = {}
    for sig in ["accX", "accY", "accZ", "gyroX", "gyroY", "gyroZ"]:
        arr = []
        for i in range(N):
            if sig.startswith("acc"):
                if spike and i > 60:
                    arr.append(35.0 if sig == "accY" else 12.0)
                else:
                    arr.append(9.8 if sig == "accY" else 0.1)
            else:
                arr.append(300.0 if spike and i > 60 else 2.0)
        samples[sig] = arr
    return samples

# Auth + onboarding
cg = http("POST", "/api/v1/auth/register",
    {"email": cg_email, "password": pw, "fullName": "CG Smoke", "role": "CAREGIVER", "locale": "es"})
cg_token = cg["accessToken"]

mon = http("POST", "/api/v1/auth/register",
    {"email": mon_email, "password": pw, "fullName": "Mon Smoke", "role": "MONITORED", "locale": "es"})
mon_token = mon["accessToken"]

person = http("POST", "/api/v1/monitored-persons",
    {"fullName": "Abuela Smoke", "birthDate": "1945-03-15", "sex": "F",
     "weightKg": 65, "heightCm": 160, "emergencyContact": "600000000"},
    token=cg_token)
person_id = person["id"]
pairing = person["pairingCode"]
device_id = f"android-smoke-{ts}"

pair_resp = http("POST", "/api/v1/devices/pair",
    {"pairingCode": pairing, "deviceId": device_id, "platform": "ANDROID"})
device_token = pair_resp["deviceToken"]

http("POST", f"/api/v1/monitored-persons/{person_id}/consent",
    {"policyVersion": "1.0-es", "acceptedBy": "MONITORED"},
    token=mon_token)

# ADL window (baseline)
now = datetime.now(timezone.utc)
start = now - timedelta(milliseconds=2500)
end = now
adl_window = {
    "monitoredPersonId": person_id,
    "deviceId": device_id,
    "windowStart": start.isoformat().replace("+00:00", "Z"),
    "windowEnd": end.isoformat().replace("+00:00", "Z"),
    "sampleRateHz": 50,
    "samples": build_samples(spike=False),
}
t0 = time.perf_counter()
adl_resp = http("POST", "/api/v1/telemetry/windows", adl_window, token=device_token)
adl_e2e_ms = int((time.perf_counter() - t0) * 1000)

# Fall-like window (spike)
start2 = end
end2 = start2 + timedelta(milliseconds=2500)
fall_window = {
    "monitoredPersonId": person_id,
    "deviceId": device_id,
    "windowStart": start2.isoformat().replace("+00:00", "Z"),
    "windowEnd": end2.isoformat().replace("+00:00", "Z"),
    "sampleRateHz": 50,
    "samples": build_samples(spike=True),
}
t1 = time.perf_counter()
fall_resp = http("POST", "/api/v1/telemetry/windows", fall_window, token=device_token)
fall_e2e_ms = int((time.perf_counter() - t1) * 1000)

# Status endpoint (MONITORED screen data source)
status = http("GET", f"/api/v1/telemetry/status/{person_id}")

out = {
    "pairingCode": pairing,
    "personId": person_id,
    "adl": {"e2eMs": adl_e2e_ms, "prediction": adl_resp["prediction"]},
    "fall": {"e2eMs": fall_e2e_ms, "prediction": fall_resp["prediction"]},
    "status": status,
}
print(json.dumps(out))
PY
)"

echo "$RESULT" | python3 -m json.tool

MODEL_VERSION="$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['fall']['prediction']['modelVersion'])")"
FALL_DETECTED="$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['fall']['prediction']['fallDetected'])")"
ADL_E2E="$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['adl']['e2eMs'])")"
FALL_E2E="$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['fall']['e2eMs'])")"
INFER_LATENCY="$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['fall']['prediction']['latencyMs'])")"

if [[ "$MODEL_VERSION" == "inference-unavailable" || "$MODEL_VERSION" == "null-response" ]]; then
  fail "Predicción en fallback ($MODEL_VERSION) — FastAPI no respondió con modelo real"
fi

ok "Pairing + consentimiento + 2 ventanas enviadas"
ok "Modelo real: $MODEL_VERSION (inferencia ${INFER_LATENCY}ms)"
ok "Latencia E2E ADL: ${ADL_E2E}ms · ventana caída simulada: ${FALL_E2E}ms (fallDetected=$FALL_DETECTED)"
echo ""
echo "Latencia medida $(date -u +%Y-%m-%dT%H:%M:%SZ):"
echo "  E2E POST /telemetry/windows (ADL):  ${ADL_E2E} ms"
echo "  E2E POST /telemetry/windows (fall):   ${FALL_E2E} ms"
echo "  FastAPI /predict (última ventana):   ${INFER_LATENCY} ms"
echo ""
ok "T1.INT smoke telemetría — PASS"
