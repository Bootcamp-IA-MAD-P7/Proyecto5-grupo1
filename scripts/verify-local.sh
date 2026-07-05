#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() { echo "✗ $1" >&2; exit 1; }
ok()   { echo "✓ $1"; }

echo "=== Fall-Sentinel — verificación local ==="

[[ -f .env ]] || fail "Falta .env — ejecuta: cp .env.example .env"

docker compose ps --status running 2>/dev/null | grep -q fallsentinel-api || fail "fallsentinel-api no corre — make up"
ok "fallsentinel-api en ejecución"

docker compose ps --status running 2>/dev/null | grep -q fallsentinel-db || fail "fallsentinel-db no corre"
ok "fallsentinel-db en ejecución"

curl -sf http://localhost:8000/health | grep -q healthy || fail "GET /health falló"
ok "GET /health"

curl -sf -X POST http://localhost:8000/predict -H 'Content-Type: application/json' \
  -d '{"accel_x":1,"accel_y":1,"accel_z":9,"gyro_x":0,"gyro_y":0,"gyro_z":0,"heart_rate":70,"room_temp":22,"room_light":100}' \
  | grep -q fall_detected || fail "POST /predict falló"
ok "POST /predict"

curl -sf http://localhost:8000/app/latest-version | grep -q version_code || fail "GET /app/latest-version falló"
ok "GET /app/latest-version (Postgres)"

LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
echo ""
echo "Flutter móvil: make flutter-phone  (o API_HOST=$LAN_IP DEVICE=<id> make flutter-local)"
