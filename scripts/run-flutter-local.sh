#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_HOST="${API_HOST:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
DEVICE="${DEVICE:-}"

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"

if [[ -z "$API_HOST" ]]; then
  echo "Define API_HOST: make flutter-local API_HOST=192.168.x.x" >&2
  exit 1
fi

API_URL="http://${API_HOST}:8000"
echo "→ API_BASE_URL=$API_URL"
[[ -n "$DEVICE" ]] && echo "→ DEVICE=$DEVICE"

cd "$ROOT/Frontend"
flutter pub get
flutter devices

ARGS=(--dart-define=API_BASE_URL="$API_URL")
[[ -n "$DEVICE" ]] && ARGS+=(-d "$DEVICE")

exec flutter run "${ARGS[@]}" "$@"
