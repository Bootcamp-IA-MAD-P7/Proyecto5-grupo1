#!/usr/bin/env bash
# T2.INT / SL-43 — MVP end-to-end: registro → caída → alerta → push → confirmar → export IT
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() { echo "✗ $1" >&2; exit 1; }
ok()   { echo "✓ $1"; }

JAVA_PORT="${JAVA_PORT:-8080}"
JAVA_URL="http://localhost:${JAVA_PORT}"
PUSH_MAX_MS=5000

echo "=== T2.INT — MVP end-to-end (SL-43) ==="

bash scripts/verify-local.sh >/dev/null || fail "Stack no sano — ejecuta: make up"

export SMOKE_JAVA_URL="$JAVA_URL"
RESULT="$(python3 - <<'PY'
import json, os, subprocess, time, urllib.request
from datetime import datetime, timezone, timedelta

JAVA = os.environ["SMOKE_JAVA_URL"]
N = 125
ts = int(time.time())
cg_email = f"cg-mvp-{ts}@sentilife.test"
mon_email = f"mon-mvp-{ts}@sentilife.test"
pw = "SmokeTest1!"
admin_email = "admin@sentilife.com"
admin_pw = "Admin1234!"

def http(method, path, data=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(JAVA + path, data=body, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=30) as r:
        raw = r.read()
        return json.loads(raw) if raw else {}

def http_text(method, path, token=None):
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(JAVA + path, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode()

def build_samples(spike=True):
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

# ── 1. Onboarding ───────────────────────────────────────────────────────────
cg = http("POST", "/api/v1/auth/register",
    {"email": cg_email, "password": pw, "fullName": "CG MVP", "role": "CAREGIVER", "locale": "es"})
cg_token = cg["accessToken"]
cg_id = cg["user"]["id"]

mon = http("POST", "/api/v1/auth/register",
    {"email": mon_email, "password": pw, "fullName": "Mon MVP", "role": "MONITORED", "locale": "es"})
mon_token = mon["accessToken"]

person = http("POST", "/api/v1/monitored-persons",
    {"fullName": "Abuela MVP", "birthDate": "1940-06-20", "sex": "F",
     "weightKg": 62, "heightCm": 158, "emergencyContact": "600111222"},
    token=cg_token)
person_id = person["id"]
pairing = person["pairingCode"]
device_id = f"android-mvp-{ts}"

http("POST", "/api/v1/devices/pair",
    {"pairingCode": pairing, "deviceId": device_id, "platform": "ANDROID"})

http("POST", f"/api/v1/monitored-persons/{person_id}/consent",
    {"policyVersion": "1.0-es", "acceptedBy": "MONITORED"},
    token=mon_token)

# ── 2. Push token CAREGIVER ─────────────────────────────────────────────────
fcm_token = f"smoke-fcm-token-{ts}"
http("POST", "/api/v1/devices/push-token",
    {"fcmToken": fcm_token, "deviceId": f"cg-device-{ts}", "platform": "ANDROID", "locale": "es"},
    token=cg_token)

# ── 3. Caída simulada (2 ventanas positivas — regla 2-de-3 T2c.6) ───────────
log_marker = f"mvp-smoke-{ts}"
now = datetime.now(timezone.utc)

def post_fall_window(offset_ms=0):
    start = now + timedelta(milliseconds=offset_ms)
    end = start + timedelta(milliseconds=2500)
    payload = {
        "monitoredPersonId": person_id,
        "deviceId": device_id,
        "windowStart": start.isoformat().replace("+00:00", "Z"),
        "windowEnd": end.isoformat().replace("+00:00", "Z"),
        "sampleRateHz": 50,
        "samples": build_samples(spike=True),
    }
    return http("POST", "/api/v1/telemetry/windows", payload)

t_fall = time.perf_counter()
first_fall = post_fall_window(0)
if not first_fall["prediction"]["fallDetected"]:
    raise SystemExit("fallDetected=false en 1ª ventana — spike no clasificado como caída")

fall_resp = post_fall_window(3000)
t_after_fall = time.perf_counter()

if not fall_resp["prediction"]["fallDetected"]:
    raise SystemExit("fallDetected=false en 2ª ventana — spike no clasificado como caída")

# Poll GET /alerts hasta ver alerta PENDING
alert_id = None
alert_ms = None
for _ in range(50):
    page = http("GET", "/api/v1/alerts?status=PENDING", token=cg_token)
    content = page.get("content", [])
    for a in content:
        if a["monitoredPersonId"] == person_id:
            alert_id = a["id"]
            alert_ms = int((time.perf_counter() - t_fall) * 1000)
            break
    if alert_id:
        break
    time.sleep(0.1)

if not alert_id:
    raise SystemExit("No se creó alerta PENDING para la persona monitorizada")

# ── 4. Latencia push (RabbitMQ → FCM intent) ────────────────────────────────
push_ms = None
push_status = "not_observed"
deadline = time.time() + 5.0
while time.time() < deadline:
    logs = subprocess.run(
        ["docker", "logs", "sentilife-backend", "--since", "30s"],
        capture_output=True, text=True
    ).stdout
    for line in logs.splitlines():
        if f"[Push] Processing alert.created: alertId={alert_id}" in line:
            push_ms = int((time.perf_counter() - t_fall) * 1000)
            push_status = "rabbitmq_processed"
        if "[FCM]" in line and ("Push sent" in line or "Error sending" in line or "Token invalid" in line):
            push_status = "fcm_attempted"
    if push_ms is not None:
        break
    time.sleep(0.2)

if push_ms is None:
    push_ms = int((time.perf_counter() - t_fall) * 1000)
    push_status = "timeout_no_push_log"

# ── 5. CAREGIVER confirma alerta ────────────────────────────────────────────
feedback = http("PATCH", f"/api/v1/alerts/{alert_id}",
    {"status": "CONFIRMED", "comment": "Caída confirmada en smoke T2.INT"},
    token=cg_token)

# ── 6. IT_ADMIN export con muestra etiquetada ───────────────────────────────
admin = http("POST", "/api/v1/auth/login",
    {"email": admin_email, "password": admin_pw})
admin_token = admin["accessToken"]
csv = http_text("GET", "/api/v1/admin/export", token=admin_token)
window_id = fall_resp["windowId"]
has_label = window_id in csv and "TRUE_FALL" in csv

out = {
    "pairingCode": pairing,
    "personId": person_id,
    "windowId": window_id,
    "alertId": alert_id,
    "fallPrediction": fall_resp["prediction"],
    "alertLatencyMs": alert_ms,
    "pushLatencyMs": push_ms,
    "pushStatus": push_status,
    "feedbackLabelId": feedback.get("feedbackLabelId"),
    "exportHasLabeledSample": has_label,
    "exportRowCount": max(0, csv.count("\n") - 1),
}
print(json.dumps(out))
PY
)"

echo "$RESULT" | python3 -m json.tool

ALERT_MS="$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['alertLatencyMs'])")"
PUSH_MS="$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['pushLatencyMs'])")"
PUSH_STATUS="$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['pushStatus'])")"
HAS_EXPORT="$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['exportHasLabeledSample'])")"
FALL_DETECTED="$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['fallPrediction']['fallDetected'])")"

[[ "$FALL_DETECTED" == "True" ]] || fail "fallDetected no es true"
[[ "$HAS_EXPORT" == "True" ]] || fail "Export IT no contiene muestra etiquetada TRUE_FALL"
[[ "$ALERT_MS" -lt "$PUSH_MAX_MS" ]] || fail "Alerta tardó ${ALERT_MS}ms (límite ${PUSH_MAX_MS}ms)"
[[ "$PUSH_MS" -lt "$PUSH_MAX_MS" ]] || fail "Push pipeline tardó ${PUSH_MS}ms (límite ${PUSH_MAX_MS}ms)"

ok "CAREGIVER registra persona + pairing + consentimiento"
ok "Caída simulada → alerta PENDING en ${ALERT_MS}ms"
ok "Push pipeline: ${PUSH_STATUS} en ${PUSH_MS}ms (< ${PUSH_MAX_MS}ms)"
ok "CAREGIVER confirma alerta con comentario"
ok "IT_ADMIN export contiene muestra etiquetada TRUE_FALL"
echo ""
echo "Latencia MVP $(date -u +%Y-%m-%dT%H:%M:%SZ):"
echo "  Alerta visible (GET /alerts):  ${ALERT_MS} ms"
echo "  Push RabbitMQ→FCM:             ${PUSH_MS} ms (${PUSH_STATUS})"
echo ""
ok "T2.INT MVP end-to-end — PASS"
