#!/usr/bin/env bash
# Prepara credenciales Firebase para Flutter (google-services.json) y backend Java.
# Uso: source .env && bash scripts/setup-firebase.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GS_TARGET="$ROOT/frontend/android/app/google-services.json"
SA_TARGET="$ROOT/backend/config/firebase-service-account.json"
PACKAGE_NAME="${FIREBASE_ANDROID_PACKAGE:-com.sentilife.app}"

mkdir -p "$ROOT/backend/config"
mkdir -p "$(dirname "$GS_TARGET")"

setup_google_services() {
  if [[ -f "$GS_TARGET" ]]; then
    echo "✓ google-services.json ya existe ($(basename "$GS_TARGET"))"
    return 0
  fi

  if [[ -n "${GOOGLE_SERVICES_JSON_PATH:-}" && -f "$GOOGLE_SERVICES_JSON_PATH" ]]; then
    cp "$GOOGLE_SERVICES_JSON_PATH" "$GS_TARGET"
    echo "✓ google-services.json copiado desde GOOGLE_SERVICES_JSON_PATH"
    return 0
  fi

  if [[ -n "${GOOGLE_SERVICES_JSON:-}" ]]; then
    printf '%s\n' "$GOOGLE_SERVICES_JSON" > "$GS_TARGET"
    echo "✓ google-services.json escrito desde GOOGLE_SERVICES_JSON"
    return 0
  fi

  if [[ -n "${FIREBASE_API_KEY:-}" && -n "${FIREBASE_APP_ID:-}" && \
        -n "${FIREBASE_MESSAGING_SENDER_ID:-}" && -n "${FIREBASE_PROJECT_ID:-}" ]]; then
    cat > "$GS_TARGET" <<EOF
{
  "project_info": {
    "project_number": "${FIREBASE_MESSAGING_SENDER_ID}",
    "project_id": "${FIREBASE_PROJECT_ID}",
    "storage_bucket": "${FIREBASE_PROJECT_ID}.appspot.com"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "${FIREBASE_APP_ID}",
        "android_client_info": {
          "package_name": "${PACKAGE_NAME}"
        }
      },
      "oauth_client": [],
      "api_key": [
        {
          "current_key": "${FIREBASE_API_KEY}"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": []
        }
      }
    }
  ],
  "configuration_version": "1"
}
EOF
    echo "✓ google-services.json generado desde FIREBASE_* en .env"
    return 0
  fi

  echo "⚠ Sin google-services.json — push Flutter deshabilitado."
  echo "  Añade GOOGLE_SERVICES_JSON_PATH o FIREBASE_API_KEY/APP_ID/MESSAGING_SENDER_ID/PROJECT_ID en .env"
  return 1
}

setup_service_account() {
  if [[ -f "$SA_TARGET" ]]; then
    echo "✓ firebase-service-account.json ya existe (backend)"
    return 0
  fi

  if [[ -n "${FIREBASE_SERVICE_ACCOUNT_PATH:-}" && -f "$FIREBASE_SERVICE_ACCOUNT_PATH" ]]; then
    cp "$FIREBASE_SERVICE_ACCOUNT_PATH" "$SA_TARGET"
    echo "✓ firebase-service-account.json copiado para backend Java"
    return 0
  fi

  local adminsdk=""
  adminsdk=$(find "$ROOT/secrets" -maxdepth 1 -name '*-firebase-adminsdk-*.json' 2>/dev/null | head -1 || true)
  if [[ -n "$adminsdk" && -f "$adminsdk" ]]; then
    cp "$adminsdk" "$SA_TARGET"
    echo "✓ firebase-service-account.json copiado desde $(basename "$adminsdk")"
    return 0
  fi

  if [[ -n "${FIREBASE_SERVICE_ACCOUNT:-}" ]]; then
    printf '%s\n' "$FIREBASE_SERVICE_ACCOUNT" > "$SA_TARGET"
    echo "✓ firebase-service-account.json escrito desde FIREBASE_SERVICE_ACCOUNT"
    return 0
  fi

  echo "⚠ Sin firebase-service-account.json — push backend deshabilitado (polling GET /alerts sigue activo)"
  return 1
}

setup_google_services || true
setup_service_account || true
