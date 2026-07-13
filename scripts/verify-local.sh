#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() { echo "✗ $1" >&2; exit 1; }
ok()   { echo "✓ $1"; }

echo "=== SentiLife — verificación local ==="

[[ -f .env ]] || fail "Falta .env — ejecuta: cp .env.example .env"

services="$(docker compose config --services)"
[[ -n "$services" ]] || fail "docker-compose.yml no define servicios"

while IFS= read -r service; do
  container_id="$(docker compose ps --all --quiet "$service" | head -n 1)"
  [[ -n "$container_id" ]] || fail "$service no tiene contenedor — ejecuta: make up"

  state="$(docker inspect --format '{{.State.Status}}' "$container_id")"
  [[ "$state" == "running" ]] || fail "$service no está en ejecución (estado: $state)"

  health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "$container_id")"
  [[ "$health" != "missing" ]] || fail "$service no define health check"
  [[ "$health" == "healthy" ]] || fail "$service no está sano (health: $health)"

  ok "$service en ejecución y sano"
done <<< "$services"

# ── Smoke tests HTTP ─────────────────────────────────────────────────────────
# Strip inline comments and whitespace when reading port values from .env
_read_port() {
  local key="$1" default="$2"
  grep -m1 "^${key}=" .env 2>/dev/null | cut -d= -f2 | cut -d'#' -f1 | tr -d ' \t' || echo "$default"
}

inference_port="${PORT:-$(_read_port PORT 8000)}"
inference_port="${inference_port:-8000}"
curl -fsS "http://localhost:${inference_port}/health" | grep -q healthy \
  || fail "GET http://localhost:${inference_port}/health falló (inference)"
ok "Inference API responde en :${inference_port}/health"

java_port="${JAVA_PORT:-$(_read_port JAVA_PORT 8080)}"
java_port="${java_port:-8080}"
curl -fsS "http://localhost:${java_port}/actuator/health" | grep -q '"status":"UP"' \
  || fail "GET http://localhost:${java_port}/actuator/health falló (Java backend)"
ok "Java backend responde en :${java_port}/actuator/health"

echo ""
LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
echo "Flutter emulador : make flutter-local"
echo "Flutter móvil    : API_HOST=${LAN_IP:-<IP_LAN>} DEVICE=<id> make flutter-phone"
echo "Smoke telemetría : make smoke-telemetry   (T1.INT / SL-25)"
echo "Smoke MVP E2E    : make smoke-mvp          (T2.INT / SL-43)"
