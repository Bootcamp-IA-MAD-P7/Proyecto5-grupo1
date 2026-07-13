# SentiLife — comandos homologados (ejecutar desde la raíz del repo)

.PHONY: up down logs verify \
        test-java test-python test-flutter test \
        flutter-local flutter-phone \
        env env-qa reset-db smoke-telemetry smoke-mvp

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
	docker compose logs -f backend api db

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
