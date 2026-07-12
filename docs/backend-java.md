# Backend Java — SentiLife

## Overview

The Java backend is the **business logic layer** of SentiLife. It handles authentication, user management, consent (GDPR), telemetry ingestion, fall alerts, push notifications, and the ML model registry. It acts as the single entry point for the Flutter app — the inference service (FastAPI) is internal and never exposed to clients.

```
Flutter App ──HTTPS+JWT──> Backend Java (Spring Boot)
                               │
                ┌──────────────┼──────────────────┐
                │              │                  │
                v              v                  v
          PostgreSQL       RabbitMQ         FastAPI (inference)
         (business data)  (alert events)    (ML predictions)
```

---

## Architecture

### Package Structure

```
com.sentilife/
├── auth/           # JWT authentication (register, login, refresh)
├── users/          # User entity + repository
├── monitored/      # Monitored persons CRUD + GDPR consent
├── consent/        # Consent entity + repository
├── telemetry/      # Sensor window ingestion + inference call
├── alerts/         # Fall alerts + caregiver feedback labels
├── devices/        # Device pairing + FCM push token registration
├── notifications/  # Firebase push + RabbitMQ event pipeline
├── registry/       # ML model registry + retrain pipeline
├── admin/          # IT admin: history, export, user management
└── config/         # Security, JWT, base entity, constants, exceptions
```

### Key Design Decisions

| Decision | Rationale |
|---|---|
| **Spring Boot 3 + Java 21** | Industry standard for enterprise APIs. Strong typing, mature ecosystem, excellent security. Demonstrates professional backend skills. |
| **JWT stateless auth** | No server-side sessions. Scales horizontally. Access token (15min) + refresh token (7 days). |
| **Flyway migrations** | Database schema versioned in code. Reproducible across environments. Never manual DDL. |
| **Synchronous prediction** | The prediction critical path (telemetry → inference → response) is synchronous HTTP for minimal latency. RabbitMQ handles only non-critical async work (push notifications). |
| **Graceful degradation** | If Firebase isn't configured → push disabled, polling works. If RabbitMQ is down → alerts still saved in DB. If inference fails → error returned but system doesn't crash. |

---

## API Endpoints

### Auth (`/api/v1/auth`)
| Method | Path | Description |
|---|---|---|
| POST | `/register` | Create account (CAREGIVER/MONITORED/IT_ADMIN) |
| POST | `/login` | Get access + refresh tokens |
| POST | `/refresh` | Renew access token |

### Monitored Persons (`/api/v1/monitored-persons`)
| Method | Path | Description |
|---|---|---|
| POST | `/` | Register a monitored person |
| GET | `/` | List caregiver's persons (paginated) |
| GET | `/{id}` | Get person details |
| DELETE | `/{id}` | GDPR deletion (cascades all data) |
| POST | `/{id}/consent` | Accept consent |
| DELETE | `/{id}/consent` | Revoke consent |

### Telemetry (`/api/v1/telemetry`)
| Method | Path | Description |
|---|---|---|
| POST | `/windows` | Ingest a sensor window → get prediction |
| GET | `/status/{id}` | Monitoring status for a person |

### Alerts (`/api/v1/alerts`)
| Method | Path | Description |
|---|---|---|
| GET | `/` | List alerts for caregiver's persons |
| PATCH | `/{id}/feedback` | Confirm/dismiss alert + feedback label |

### Devices (`/api/v1/devices`)
| Method | Path | Description |
|---|---|---|
| POST | `/pair` | Pair device with pairing code |
| POST | `/push-token` | Register FCM token for push |

### Admin (`/api/v1/admin`)
| Method | Path | Description |
|---|---|---|
| GET | `/history` | Global alert history |
| GET | `/export` | Labelled dataset as CSV |
| GET | `/users` | List all users |
| PATCH | `/users/{id}` | Activate/deactivate user |

### Model Registry (`/api/v1/admin/models`)
| Method | Path | Description |
|---|---|---|
| POST | `/` | Register new model version |
| POST | `/{version}/promote` | Promote CANDIDATE → ACTIVE |
| GET | `/` | List all model versions |
| GET | `/active` | Get current active model |

### Retrain (`/api/v1/admin/retrain`)
| Method | Path | Description |
|---|---|---|
| POST | `/` | Trigger retraining job |
| GET | `/status` | Poll job progress |

---

## Local Setup

### Prerequisites

- **Java 21** (OpenJDK or Microsoft Build)
- **Docker Desktop** (for PostgreSQL, RabbitMQ, and the full stack)
- **Maven** (optional — the project includes `mvnw.cmd` wrapper)

### Option A: Full stack with Docker (recommended)

From the project root:

```bash
# Copy environment template
cp .env.example .env

# Start everything (PostgreSQL, RabbitMQ, Java, FastAPI, Prometheus, Grafana)
docker compose up --build

# If you get schema errors, wipe volumes first:
docker compose down -v
docker compose up --build
```

Services available at:
- Java backend: http://localhost:8080/actuator/health
- Inference: http://localhost:8000/health
- Grafana: http://localhost:3000 (admin/admin)
- RabbitMQ: http://localhost:15672 (guest/guest)
- Prometheus: http://localhost:9090

### Option B: Java tests only (no Docker needed)

```bash
cd backend-java
.\mvnw.cmd test
```

This uses H2 in-memory database — no PostgreSQL required. All 18 tests run in ~20 seconds.

### Option C: Java backend standalone (needs PostgreSQL + RabbitMQ)

```bash
# Start only the dependencies
docker compose up db rabbitmq -d

# Run the Java backend outside Docker
cd backend-java
.\mvnw.cmd spring-boot:run
```

---

## Technology Stack — Why Each Choice

### Spring Boot 3

**What it is:** Java framework for building production-ready APIs with minimal configuration.

**Why we chose it:**
- Convention over configuration — starter dependencies handle 90% of boilerplate
- Built-in security (Spring Security), data access (Spring Data JPA), validation
- Actuator provides health checks and Prometheus metrics out of the box
- Mature ecosystem: every problem has a solution, every library integrates
- Professional standard in enterprise — relevant for job interviews

### Java 21

**What it is:** Latest LTS (Long-Term Support) version of Java.

**Why we chose it:**
- Virtual threads (Project Loom) — future scalability
- Pattern matching, records, sealed classes — cleaner code
- 10+ years of security patches guaranteed (LTS)
- Required by Spring Boot 3.x

### PostgreSQL 16

**What it is:** Relational database with JSONB support.

**Why we chose it:**
- ACID transactions for business data (users, consents, alerts)
- JSONB columns for flexible telemetry data (no schema migration needed per sensor change)
- Partial unique indexes (e.g., only one ACTIVE consent per person)
- Industry standard, free, battle-tested at scale

### Flyway

**What it is:** Database migration tool — SQL scripts versioned with the code.

**Why we chose it:**
- Schema changes are tracked in git (V1, V2, V3...)
- Every environment (dev, CI, production) gets the exact same schema
- No manual DDL ever — `docker compose up` creates everything from scratch
- Rollbacks are explicit, never implicit

### RabbitMQ

**What it is:** Message broker for asynchronous event processing.

**Why we chose it:**
- Decouples the critical path (prediction) from non-critical work (push notifications)
- If FCM is slow or down, the alert is still saved — push is retried later
- Exchanges + routing keys allow adding new consumers without modifying producers
- Management UI for debugging message flow

### Firebase Admin SDK (FCM)

**What it is:** Server-side SDK to send push notifications to mobile devices.

**Why we chose it:**
- The Flutter app already uses Firebase (App Distribution)
- Works with app in foreground, background, or terminated
- Data payload allows navigation directly to the alert detail screen
- Graceful fallback: if not configured, alerts work via polling

### Prometheus + Grafana

**What Prometheus is:** Time-series database that scrapes metrics from services.
**What Grafana is:** Dashboard UI that visualizes Prometheus data.

**Why we chose them:**
- Spring Boot Actuator exposes metrics with zero code (request count, latency, JVM stats)
- Custom metrics for business KPIs (predictions/s, alerts/min, model version)
- Grafana dashboards are versioned as JSON — reproducible across environments
- Industry standard for observability (used by Netflix, Spotify, etc.)

### JWT (JSON Web Tokens)

**What it is:** Stateless authentication tokens signed with a secret key.

**Why we chose it:**
- No server-side session storage — each request carries its own auth
- Scales horizontally (any backend instance can validate the token)
- Roles embedded as claims — no DB lookup per request for authorization
- Short-lived access (15min) + long-lived refresh (7 days) balances security and UX

### H2 (test only)

**What it is:** In-memory Java database used exclusively for tests.

**Why we chose it:**
- Tests run in <2 seconds without any external dependencies
- CI doesn't need PostgreSQL containers
- Schema created on the fly by Hibernate (create-drop mode)

---

## Testing

### Unit Tests (Mockito)
- `AuthServiceTest` — login, register, refresh, password validation
- `MonitoredServiceTest` — consent management, GDPR deletion, access control
- `TelemetryServiceTest` — consent filter, fall detection alert creation

### Integration Test
- `SentiLifeApplicationTests` — verifies the full Spring context loads with H2

### Running locally
```bash
cd backend-java
.\mvnw.cmd test
```

### CI
GitHub Actions runs `mvn test` on every push to `feature/backend` and `main`. See `.github/workflows/backend-ci.yml`.

---

## Database Schema

Managed by Flyway migrations in `src/main/resources/db/migration/`:

- **V1** — Full schema: users, monitored_persons, consents, alerts, feedback_labels, telemetry_windows, paired_devices, push_tokens, model_registry, app_versions
- **V2** — Seed IT_ADMIN user
- **V3** — Add created_at columns for BaseEntity audit

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `POSTGRES_USER` | fallsentinel | Database user |
| `POSTGRES_PASSWORD` | fallsentinel123 | Database password |
| `POSTGRES_DB` | fallsentinel | Database name |
| `JWT_SECRET` | dev-secret... | JWT signing key (min 32 chars) |
| `RABBITMQ_USER` | guest | RabbitMQ user |
| `RABBITMQ_PASSWORD` | guest | RabbitMQ password |
| `INFERENCE_URL` | http://api:8000 | FastAPI inference service URL |
| `FIREBASE_SERVICE_ACCOUNT` | (empty) | Path to Firebase JSON (optional) |

---

## Security

- All passwords hashed with BCrypt (cost 12)
- JWT validated on every request (except public endpoints)
- Consent required before telemetry is accepted (403 otherwise)
- GDPR right to erasure: cascading delete of all personal data
- Firebase tokens auto-cleaned when invalid/unregistered


---

## A/B Testing (SL-57)

### How it works

When a CANDIDATE model exists in the registry, ~20% of prediction traffic is tagged for the candidate:

1. `ABTestingService.decide()` rolls a random number — 80% → ACTIVE, 20% → CANDIDATE
2. The prediction is made (currently always by the loaded model)
3. Prometheus counters track predictions per model status (`ab_testing_predictions_total{model_status="ACTIVE|CANDIDATE"}`)
4. Once enough feedback accumulates, the team can compare ACTIVE vs. CANDIDATE performance in Grafana

### Prometheus metrics

| Metric | Labels | Description |
|---|---|---|
| `ab_testing_predictions_total` | `model_status=ACTIVE` | Predictions served by active model |
| `ab_testing_predictions_total` | `model_status=CANDIDATE` | Predictions routed to candidate |

### Viewing in Grafana

Query: `sum by (model_status) (rate(ab_testing_predictions_total[5m]))`

This shows the traffic split in real time.


---

## Grafana Dashboard (SL-47)

The definitive dashboard at `observability/grafana/dashboards/sentilife-pipeline.json` includes:

| Panel | What it shows |
|---|---|
| Service Health | UP/DOWN status for all services |
| Request Rate | Requests per second per endpoint |
| Response Time p95 | 95th percentile latency per endpoint |
| Inference Latency | p50/p95/p99 for `/predict` |
| Predictions by Result | Falls vs ADL vs Errors counters |
| A/B Traffic Split | Pie chart: ACTIVE vs CANDIDATE model |
| Alerts per Minute | Rate of fall alerts created |
| RabbitMQ Throughput | Messages published/delivered per second |
| E2E Latency Gauge | Telemetry ingestion p95 with thresholds (green <2s, yellow <5s, red >5s) |
| Model Registry | Current model versions and their traffic |
| JVM Memory | Heap usage for the Java backend |

Access at: http://localhost:3000 (admin/admin) → Dashboards → SentiLife

---

## A/B Testing (SL-57)

Routes ~20% of prediction traffic to a CANDIDATE model when one exists in the registry.

**How it works:**
1. `ABTestingService.decide()` rolls a random number on each prediction
2. 80% → ACTIVE model, 20% → CANDIDATE model
3. Prometheus counters track `ab_testing_predictions_total{model_status="ACTIVE|CANDIDATE"}`
4. Grafana pie chart shows the split in real time

**Metrics visible in Grafana:**
- Traffic split ratio (should be ~80/20)
- Per-model prediction counts
- Once feedback is collected, recall per version can be computed

**To test:** Register a CANDIDATE model via `POST /api/v1/admin/models`, then send telemetry — Grafana will show the split.
