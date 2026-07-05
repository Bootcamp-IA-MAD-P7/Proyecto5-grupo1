# Fall-Sentinel — comandos homologados (ejecutar desde la raíz del repo)

.PHONY: up down logs verify flutter-local flutter-phone env reset-db test-backend

env:
	@test -f .env || cp .env.example .env
	@echo ".env listo"

up: env
	docker compose up --build -d
	@sleep 10
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

flutter-local:
	bash scripts/run-flutter-local.sh

# Atajo: usa DEVICE del .env o variable de entorno
flutter-phone:
	@set -a && . ./.env 2>/dev/null; set +a; \
	 API_HOST=$${API_HOST:-$$(hostname -I | awk '{print $$1}')} \
	 DEVICE=$${DEVICE:-} \
	 bash scripts/run-flutter-local.sh

test-backend:
	cd Backend && pip install -r requirements.txt pytest httpx && pytest tests/ -v
