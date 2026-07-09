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

api_port="${PORT:-$(sed -n 's/^PORT=//p' .env | tail -n 1)}"
api_port="${api_port:-8000}"
curl -fsS "http://localhost:${api_port}/health" | grep -q healthy \
  || fail "GET http://localhost:${api_port}/health falló"
ok "API local responde en /health"

LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
echo ""
echo "Flutter emulador: make flutter-local"
echo "Flutter móvil: API_HOST=${LAN_IP:-<IP_LAN>} DEVICE=<id> make flutter-local"
