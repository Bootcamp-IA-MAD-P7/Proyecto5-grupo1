#!/usr/bin/env bash
# T3.INT — Smoke QA contra EC2 (:8005) sin stack local.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() { echo "✗ $1" >&2; exit 1; }
ok()   { echo "✓ $1"; }

EC2_HOST="${EC2_HOST:-100.52.221.179}"
EC2_PORT="${EC2_PORT:-8005}"
JAVA_URL="http://${EC2_HOST}:${EC2_PORT}"
GRAFANA_URL="${GRAFANA_URL:-http://${EC2_HOST}:3000}"

echo "=== T3.INT — Smoke QA EC2 (${JAVA_URL}) ==="

OTA="$(curl -sf --max-time 10 "${JAVA_URL}/app/latest-version" || fail "OTA unreachable")"
VC="$(echo "$OTA" | python3 -c "import sys,json; print(json.load(sys.stdin)['version_code'])")"
ok "OTA latest-version → version_code=${VC}"

export SMOKE_JAVA_URL="$JAVA_URL"
export SMOKE_SKIP_VERIFY=1
export SMOKE_SKIP_DOCKER_LOGS=1
bash scripts/smoke-mvp-e2e.sh

if curl -sf --max-time 5 "${GRAFANA_URL}/api/health" >/dev/null 2>&1; then
  ok "Grafana UP (${GRAFANA_URL})"
else
  echo "⚠ Grafana no accesible desde esta red (${GRAFANA_URL}) — puerto 3000 interno en EC2"
fi

echo ""
ok "T3.INT QA EC2 — PASS"
echo "  Java : ${JAVA_URL}/actuator/health"
echo "  OTA  : version_code=${VC}"
echo "  Fecha: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
