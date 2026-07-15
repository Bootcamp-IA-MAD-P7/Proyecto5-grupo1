#!/usr/bin/env bash
# T4.INT — Demo experto MLOps: retrain IT → decisión → drift → A/B Prometheus
# Sin stubs: POST /train real, PSI real, métricas Prometheus reales.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() { echo "✗ $1" >&2; exit 1; }
ok()   { echo "✓ $1"; }

JAVA_PORT="${JAVA_PORT:-8080}"
INFERENCE_PORT="${PORT:-8000}"
PROM_PORT="${PROMETHEUS_PORT:-9090}"
JAVA_URL="${SMOKE_JAVA_URL:-http://localhost:${JAVA_PORT}}"
INFERENCE_URL="http://localhost:${INFERENCE_PORT}"
PROM_URL="http://localhost:${PROM_PORT}"
POLL_INTERVAL=2
POLL_MAX=600   # retrain puede tardar varios minutos

echo "=== T4.INT — Demo experto MLOps ==="
echo "→ Java API:      ${JAVA_URL}"
echo "→ Inference API: ${INFERENCE_URL}"
echo "→ Prometheus:    ${PROM_URL}"

if [[ "${SMOKE_SKIP_VERIFY:-0}" != "1" ]]; then
  bash scripts/verify-local.sh >/dev/null || fail "Stack no sano — ejecuta: make up"
else
  curl -sf --max-time 10 "${JAVA_URL}/actuator/health" | grep -q '"status":"UP"' \
    || fail "Java health not UP at ${JAVA_URL}"
  ok "Java health UP (remote)"
fi

export SMOKE_JAVA_URL="$JAVA_URL"
export SMOKE_INFERENCE_URL="$INFERENCE_URL"
export SMOKE_PROM_URL="$PROM_URL"
export SMOKE_POLL_INTERVAL="$POLL_INTERVAL"
export SMOKE_POLL_MAX="$POLL_MAX"

RESULT="$(python3 - <<'PY'
import json, os, re, sys, time, urllib.request, urllib.parse
from datetime import datetime, timezone, timedelta

JAVA = os.environ["SMOKE_JAVA_URL"]
INFERENCE = os.environ["SMOKE_INFERENCE_URL"]
PROM = os.environ["SMOKE_PROM_URL"]
POLL_INTERVAL = int(os.environ["SMOKE_POLL_INTERVAL"])
POLL_MAX = int(os.environ["SMOKE_POLL_MAX"])
N = 125
ts = int(time.time())
admin_email = "admin@sentilife.com"
admin_pw = "Admin1234!"
cg_email = f"cg-mlops-{ts}@sentilife.test"
mon_email = f"mon-mlops-{ts}@sentilife.test"
pw = "SmokeTest1!"

def http(method, base, path, data=None, token=None, timeout=60):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(base + path, data=body, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read()
        return json.loads(raw) if raw else {}

def http_text(url, timeout=30):
    with urllib.request.urlopen(url, timeout=timeout) as r:
        return r.read().decode()

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

def prom_value(expr):
    q = urllib.parse.quote(expr)
    data = json.loads(http_text(f"{PROM}/api/v1/query?query={q}"))
    results = data.get("data", {}).get("result", [])
    if not results:
        return None
    return float(results[0]["value"][1])

cg = http("POST", JAVA, "/api/v1/auth/register",
    {"email": cg_email, "password": pw, "fullName": "CG MLOps", "role": "CAREGIVER", "locale": "es"})
cg_token = cg["accessToken"]

mon = http("POST", JAVA, "/api/v1/auth/register",
    {"email": mon_email, "password": pw, "fullName": "Mon MLOps", "role": "MONITORED", "locale": "es"})
mon_token = mon["accessToken"]

person = http("POST", JAVA, "/api/v1/monitored-persons",
    {"fullName": "MLOps Demo", "birthDate": "1945-03-15", "sex": "F",
     "weightKg": 65, "heightCm": 160, "emergencyContact": "600000000",
     "monitoredUserEmail": mon_email}, token=cg_token)
person_id = person["id"]
pairing = person["pairingCode"]
device_id = f"mlops-{ts}"

pair = http("POST", JAVA, "/api/v1/devices/pair",
    {"pairingCode": pairing, "deviceId": device_id, "platform": "ANDROID"})
device_token = pair["deviceToken"]

http("POST", JAVA, f"/api/v1/monitored-persons/{person_id}/consent",
    {"policyVersion": "1.0-es", "acceptedBy": "MONITORED"}, token=mon_token)

windows_sent = 0
now = datetime.now(timezone.utc)
for i, spike in enumerate([False, False, True]):
    start = now + timedelta(milliseconds=i * 2600)
    end = start + timedelta(milliseconds=2500)
    payload = {
        "monitoredPersonId": person_id,
        "deviceId": device_id,
        "windowStart": start.isoformat().replace("+00:00", "Z"),
        "windowEnd": end.isoformat().replace("+00:00", "Z"),
        "sampleRateHz": 50,
        "samples": build_samples(spike=spike),
    }
    http("POST", JAVA, "/api/v1/telemetry/windows", payload, token=device_token, timeout=30)
    windows_sent += 1

# ── 2. Drift visible (FastAPI) ──────────────────────────────────────────────
drift = http("GET", INFERENCE, "/drift")
psi = drift.get("psi")
drift_detected = drift.get("drift_detected")
samples = drift.get("samples", 0)
if psi is None:
    raise SystemExit("GET /drift no devolvió PSI")
if samples < 1:
    raise SystemExit(f"Buffer drift vacío (samples={samples})")

# ── 3. IT_ADMIN lanza retrain ───────────────────────────────────────────────
admin = http("POST", JAVA, "/api/v1/auth/login",
    {"email": admin_email, "password": admin_pw})
admin_token = admin["accessToken"]

trigger = http("POST", JAVA, "/api/v1/admin/retrain", token=admin_token)
if trigger.get("phase") != "DRIFT":
    raise SystemExit(f"Retrain no arrancó en DRIFT: {trigger}")

phases_seen = {trigger["phase"]}
start = time.time()
status = trigger

while status.get("phase") not in ("COMPLETED", "FAILED"):
    if time.time() - start > POLL_MAX:
        raise SystemExit(f"Timeout retrain tras {POLL_MAX}s — última fase: {status.get('phase')}")
    time.sleep(POLL_INTERVAL)
    status = http("GET", JAVA, "/api/v1/admin/retrain/status", token=admin_token)
    phases_seen.add(status.get("phase"))

if status.get("phase") == "FAILED":
    raise SystemExit(f"Retrain FAILED: {status.get('message')}")

decision = status.get("decision")
if decision not in ("PROMOTED", "CANDIDATE", "DISCARDED"):
    raise SystemExit(f"Decisión inválida: {decision}")

metrics = status.get("metrics") or {}
recall = metrics.get("recall") or metrics.get("recall_fall")
overfitting = metrics.get("overfitting")
if recall is None or overfitting is None:
    raise SystemExit(f"Métricas reales ausentes en status: {metrics}")

# ── 4. Registry + drift post-retrain ────────────────────────────────────────
registry = http("GET", INFERENCE, "/model/registry")
models = registry.get("models", [])
if not models:
    raise SystemExit("Registry vacío")

drift_after = http("POST", INFERENCE, "/drift/recompute")
if drift_after.get("psi") is None:
    raise SystemExit("POST /drift/recompute sin PSI")

# ── 5. A/B + drift en Prometheus ────────────────────────────────────────────
ab_active = prom_value('ab_testing_predictions_total{model_status="ACTIVE"}')
ab_candidate = prom_value('ab_testing_predictions_total{model_status="CANDIDATE"}')
drift_psi_prom = prom_value("feature_drift_psi")
drift_samples_prom = prom_value("feature_drift_samples")

if ab_active is None and ab_candidate is None:
    raise SystemExit("Sin métricas ab_testing_predictions_total en Prometheus")

out = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "windows_sent": windows_sent,
    "drift": {"psi": psi, "drift_detected": drift_detected, "samples": samples},
    "retrain": {
        "phases_seen": sorted(phases_seen),
        "decision": decision,
        "model_version": status.get("modelVersion"),
        "message": status.get("message"),
        "recall": float(recall),
        "overfitting": float(overfitting),
        "elapsed_s": round(time.time() - start, 1),
    },
    "registry_models": len(models),
    "prometheus": {
        "ab_active": ab_active,
        "ab_candidate": ab_candidate,
        "feature_drift_psi": drift_psi_prom,
        "feature_drift_samples": drift_samples_prom,
    },
}
print(json.dumps(out))
PY
)"

echo "$RESULT" | python3 -m json.tool

DECISION="$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['retrain']['decision'])")"
RECALL="$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['retrain']['recall'])")"
OVERFITTING="$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['retrain']['overfitting'])")"
ELAPSED="$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['retrain']['elapsed_s'])")"
PSI="$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['drift']['psi'])")"

ok "Telemetría real → buffer drift poblado"
ok "Drift PSI=${PSI} visible (GET /drift)"
ok "Retrain IT_ADMIN completado: decisión=${DECISION} recall=${RECALL} overfitting=${OVERFITTING} (${ELAPSED}s)"
ok "Registry y métricas Prometheus A/B + drift verificadas"
echo ""
echo "=== T4.INT PASS — demo experto MLOps sin stubs ==="
echo "Grafana: http://localhost:3000 → panel PSI + A/B predictions"
echo "Flutter: login IT_ADMIN → pestaña MLOps (mismo flujo manual)"
