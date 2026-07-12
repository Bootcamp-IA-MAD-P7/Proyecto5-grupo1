# Daily Scrum — josejob

## 09/07/2026

### What did I do?

- **SL-1 (Kickoff)** — Roadmap, SDD, and constitution approved. Contracts frozen. Streams assigned.
- **SL-8 (Renombrado SentiLife)** — Full rename to `com.sentilife.app` across all platforms (Android, iOS, Web, Windows, Linux)
- **SL-10 (Mock de contratos Flutter)** — Created all service mocks implementing spec §6 contracts:
  - `auth_service.dart`, `monitored_service.dart`, `telemetry_service.dart`, `alerts_service.dart`, `devices_service.dart`, `admin_service.dart`
  - Models: `User`, `MonitoredPerson`, `Alert`, `RetrainJobStatus` + `exceptions.dart`
  - 32 unit tests passing
- **SL-2 (Java structure)** — Created `backend-java/` from scratch: Spring Boot 3 + Java 21, Dockerfile, `/actuator/health`
- **SL-3 (Flyway migrations)** — V1 full schema (9 tables) + V2 seed IT_ADMIN
- **SL-21 (Telemetry ingestion)** — POST /telemetry/windows: persist → inference sync → prediction
- **SL-22 (/devices/pair)** — Device pairing with pairingCode
- **SL-26 (Auth JWT)** — Register, login, refresh, BCrypt, JWT roles, Spring Security filter
- **SL-27 (CRUD personas)** — Full CRUD with caregiver ownership checks
- **SL-28 (Consent + 403)** — Consent accept/revoke, telemetry blocked without consent
- **SL-34 (Alerts + feedback)** — Alert persistence, GET paginated, PATCH with feedback label
- **SL-36 (Export dataset)** — GET /admin/export CSV with date range
- **SL-46 (Java tests)** — 18 tests: auth, consent, telemetry, context loads
- **SL-48 (GDPR suppression)** — Cascading delete of all personal data
- Refactored: `BaseEntity`, `DomainExceptions` hierarchy, `DomainConstants`

---

## 10/07/2026

### What did I do?

- **SL-44 (CI pipeline)** — Created `.github/workflows/backend-ci.yml`:
  - `test-java`: JDK 21 + `mvn test` on push to feature/backend and main
  - `test-python`: pytest for inference service
  - `build-and-push`: Docker images for Java + FastAPI (on main merge)
  - `deploy`: SSH to EC2, compose up, health checks
- **SL-5 (Docker Compose complete)** — Added Prometheus and Grafana:
  - `observability/prometheus.yml` scraping Java actuator, FastAPI /metrics, RabbitMQ
  - Grafana auto-provisioned datasource + skeleton dashboard
  - All services with health checks and proper dependency chain
- **SL-7 (FastAPI inference only)** — Rewrote `Backend/api/main.py`:
  - Removed OTA endpoints, db.py, PostgreSQL dependency
  - New: /predict (loads model.pkl), /health, /metrics, /model/info, /model/reload
  - Hot-reload support, Prometheus latency histogram
  - Removed psycopg2 from requirements

---

## 11/07/2026

### What did I do?

- **SL-35 (Push FCM backend)** — Firebase Cloud Messaging:
  - `FirebaseConfig`: graceful degradation if no service account
  - `NotificationService`: push to caregiver devices on fall alert
  - RabbitMQ pipeline: `AlertEventPublisher` → exchange → `AlertPushListener`
  - Auto-cleanup of invalid tokens. Fallback: polling via GET /alerts
- **SL-54 (Model registry + hot-reload)** — Registry package:
  - `ModelVersion` entity, `ModelVersionRepository`
  - `RegistryService`: register CANDIDATE, promote ACTIVE, retire old, trigger reload
  - `RegistryController`: POST /admin/models, POST /{version}/promote, GET /active
- **SL-55 (Retrain pipeline)** — Async retraining with decision logic:
  - Phases: DRIFT → TRAINING → EVALUATING → DECIDING → COMPLETED
  - Decision: recall > 80% AND overfitting < 5% → auto-promote
  - POST /admin/retrain + GET /admin/retrain/status
- Fixed Docker locally: V3 migration adding missing `created_at` columns, removed stale db/init volume

---

## 12/07/2026

### What did I do?

- **SL-57 (A/B testing)** — Routes ~20% traffic to CANDIDATE model:
  - `ABTestingService` with Prometheus counters per model status
  - Wired into TelemetryService for metric tracking
- **SL-47 (Grafana dashboard definitivo)** — Complete dashboard:
  - Service health, request rate, p95 latency, inference latency (p50/p95/p99)
  - Predictions by result, A/B traffic split, alerts/min, RabbitMQ throughput
  - E2E latency gauge with thresholds, JVM memory
- **Code quality refactor** — Extracted model status constants to `DomainConstants`
- **Merged dev into feature/backend** — Reconciled team's ML and FE work
- **Fixed Python CI** — Updated `test_inference_api.py` to match new inference contract
- **Docs** — Created `docs/backend-java.md` (architecture, setup, tech justifications)
- **PR #34** opened: `feature/backend` → `dev`
