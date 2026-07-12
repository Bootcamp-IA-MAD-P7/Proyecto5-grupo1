# Fall-Sentinel — comandos homologados (ejecutar desde la raíz del repo)

.PHONY: up down logs verify flutter-local flutter-phone flutter-qa env env-qa reset-db test-backend

env:
	@test -f .env || cp .env.example .env
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
	docker compose logs -f fallsentinel-api fallsentinel-db

verify:
	bash scripts/verify-local.sh

flutter-local: verify
	bash scripts/run-flutter-local.sh

# Atajo: usa DEVICE del .env o variable de entorno
flutter-phone:
	@set -a && . ./.env 2>/dev/null; set +a; \
	 API_HOST=$${API_HOST:-$$(hostname -I | awk '{print $$1}')} \
	 DEVICE=$${DEVICE:-} \
	 bash scripts/run-flutter-local.sh

env-qa:
	@test -f .env.qa || cp .env.qa.example .env.qa
	@echo ".env.qa listo (API QA en EC2)"

flutter-qa: env-qa
	@set -a && . ./.env.qa; set +a; \
	 DEVICE=$${DEVICE:-} \
	 bash scripts/run-flutter-qa.sh

test-backend:
	cd inference && pip install -r requirements.txt pytest httpx && pytest tests/ -v
