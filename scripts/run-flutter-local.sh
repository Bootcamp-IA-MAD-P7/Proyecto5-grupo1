#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${DEVICE:-}"
API_HOST="${API_HOST:-10.0.2.2}"
API_PORT="${API_PORT:-8000}"
API_BASE_URL="${API_BASE_URL:-http://${API_HOST}:${API_PORT}}"

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"

echo "→ API_BASE_URL=$API_BASE_URL"
[[ -n "$DEVICE" ]] && echo "→ DEVICE=$DEVICE"

cd "$ROOT/frontend"
flutter pub get
flutter devices

ARGS=(--dart-define=API_BASE_URL="$API_BASE_URL")
[[ -n "$DEVICE" ]] && ARGS+=(-d "$DEVICE")

exec flutter run "${ARGS[@]}" "$@"
