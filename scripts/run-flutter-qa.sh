#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${DEVICE:-}"

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"

if [[ -f "$ROOT/.env.qa" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ROOT/.env.qa"
  set +a
fi

bash "$ROOT/scripts/setup-firebase.sh" || true

API_URL="${API_BASE_URL:-http://${QA_API_HOST:-100.52.221.179}:${QA_API_PORT:-8005}}"

echo "→ QA API_BASE_URL=$API_URL"
[[ -n "$DEVICE" ]] && echo "→ DEVICE=$DEVICE"

cd "$ROOT/frontend"
flutter pub get
flutter devices

ARGS=(--dart-define=API_BASE_URL="$API_URL")
while IFS= read -r define; do
  [[ -n "$define" ]] && ARGS+=("$define")
done < <(bash "$ROOT/scripts/firebase-dart-defines.sh")
[[ -n "$DEVICE" ]] && ARGS+=(-d "$DEVICE")

exec flutter run "${ARGS[@]}" "$@"
