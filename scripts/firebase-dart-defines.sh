#!/usr/bin/env bash
# Añade --dart-define FIREBASE_* si están definidos en el entorno.
firebase_dart_defines() {
  local defines=()
  [[ -n "${FIREBASE_API_KEY:-}" ]] &&
    defines+=(--dart-define=FIREBASE_API_KEY="${FIREBASE_API_KEY}")
  [[ -n "${FIREBASE_APP_ID:-}" ]] &&
    defines+=(--dart-define=FIREBASE_APP_ID="${FIREBASE_APP_ID}")
  [[ -n "${FIREBASE_MESSAGING_SENDER_ID:-}" ]] &&
    defines+=(--dart-define=FIREBASE_MESSAGING_SENDER_ID="${FIREBASE_MESSAGING_SENDER_ID}")
  [[ -n "${FIREBASE_PROJECT_ID:-}" ]] &&
    defines+=(--dart-define=FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID}")
  printf '%s\n' "${defines[@]}"
}
