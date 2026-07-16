# SentiLife — comandos homologados (ejecutar desde la raíz del repo)

.PHONY: up down logs verify \
        test-java test-python test-flutter test \
        flutter-local flutter-phone flutter-qa apk-qa \
        env env-qa reset-db smoke-telemetry smoke-mvp smoke-qa-ec2 smoke-expert smoke-assistant

# ── Entorno local ─────────────────────────────────────────────────────────────
env:
	@test -f .env || cp .env.example .env
	@set -a && . ./.env 2>/dev/null; set +a; bash scripts/setup-firebase.sh || true
	@echo ".env listo"

up: env
	docker compose up --build -d --wait
	@$(MAKE) verify

down:
	docker compose down

reset-db:
	docker compose down -v
	@echo "Volumen Postgres borrado. Ejecuta: make up"

logs:
	docker compose logs -f backend api assistant db

# ── Tests ─────────────────────────────────────────────────────────────────────
# Corren exactamente igual que en CI (ver .github/workflows/ci.yml)

test-java:
	cd backend && mvn test -B

test-python:
	cd inference && pip install -q -r requirements.txt pytest httpx && \
	  PYTHONPATH=$(CURDIR)/inference pytest tests/ -v --tb=short

test-flutter:
	cd frontend && flutter pub get && flutter analyze && flutter test --reporter=expanded

test: test-java test-python test-flutter
	@echo "✅ Todos los tests pasaron"

# ── Verificación de salud local ───────────────────────────────────────────────
verify:
	bash scripts/verify-local.sh

# T1.INT / SL-25 — smoke telemetría real (requiere make up)
smoke-telemetry: verify
	bash scripts/smoke-telemetry-e2e.sh

# T2.INT / SL-43 — MVP end-to-end (requiere make up + Firebase configurado)
smoke-mvp: verify
	bash scripts/smoke-mvp-e2e.sh

# T3.INT — smoke QA contra EC2 :8005 (sin stack local)
smoke-qa-ec2:
	bash scripts/smoke-qa-ec2.sh

# T4.INT — demo experto MLOps: retrain IT → decisión → drift → A/B (requiere make up)
smoke-expert: verify
	bash scripts/smoke-expert-mlops.sh

# T6.8 / T6.INT — asistente IA (RAG + tools IT_ADMIN)
smoke-assistant: verify
	bash scripts/smoke-assistant.sh

# ── Flutter ───────────────────────────────────────────────────────────────────
flutter-local: verify
	bash scripts/run-flutter-local.sh

flutter-phone:
	@set -a && . ./.env 2>/dev/null; set +a; \
	 API_HOST=$${API_HOST:-$$(hostname -I | awk '{print $$1}')} \
	 DEVICE=$${DEVICE:-} \
	 bash scripts/run-flutter-local.sh

# ── Entorno QA (contra EC2) ───────────────────────────────────────────────────
env-qa:
	@test -f .env.qa || cp .env.qa.example .env.qa 2>/dev/null || \
	  echo "⚠ Crea .env.qa con API_HOST=<EC2_IP>"
	@set -a && . ./.env.qa 2>/dev/null; set +a; bash scripts/setup-firebase.sh || true

flutter-qa: env-qa
	@set -a && . ./.env.qa; set +a; \
	 DEVICE=$${DEVICE:-} \
	 bash scripts/run-flutter-qa.sh

# APK release apuntando a Java API en EC2 QA (:8005)
# Sin key.properties firma con debug (apto QA). Con keystore CI → firma release.
apk-qa:
	@API_URL=$${API_BASE_URL:-http://100.52.221.179:8005}; \
	 echo "→ Building APK QA → $$API_URL"; \
	 cd frontend && flutter pub get && \
	 flutter build apk --release \
	   --dart-define=API_BASE_URL=$$API_URL && \
	 ls -lh build/app/outputs/flutter-apk/app-release.apk && \
	 echo "✅ APK: frontend/build/app/outputs/flutter-apk/app-release.apk"
