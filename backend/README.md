# Backend Java — SentiLife

Backend de negocio con Spring Boot 3 + Java 21. Gestiona autenticación, usuarios, personas monitorizadas, consentimiento, alertas, notificaciones push y administración.

## Requisitos

- Java 21
- Maven 3.9+
- PostgreSQL 16 (o vía Docker Compose)
- RabbitMQ 3.13 (o vía Docker Compose)

## Inicio rápido

### Con Docker (recomendado)

```bash
# Desde la raíz del repo
cp .env.example .env
docker compose up backend
```

El servicio queda en **http://localhost:8080**

- Health: http://localhost:8080/actuator/health
- **Swagger UI:** http://localhost:8080/swagger-ui.html
- OpenAPI JSON: http://localhost:8080/v3/api-docs
- Métricas Prometheus: http://localhost:8080/actuator/prometheus

### Local (sin Docker)

```bash
cd backend
mvn clean install
mvn spring-boot:run
```

Requiere PostgreSQL y RabbitMQ corriendo en localhost con las credenciales de `application.yml`.

## Tests

```bash
mvn test
```

Los tests usan H2 en memoria (perfil `test`), no requieren PostgreSQL.

## Estructura

```
backend/
├── src/main/java/com/sentilife/
│   ├── SentiLifeApplication.java   # Entrada
│   ├── config/                     # Security, RabbitMQ, etc.
│   ├── auth/                       # JWT, login, registro
│   ├── users/                      # Gestión de usuarios
│   ├── monitored/                  # Personas monitorizadas
│   ├── consent/                    # Consentimiento GDPR
│   ├── telemetry/                  # Ingesta ventanas + clasificación
│   ├── alerts/                     # Alertas + feedback
│   ├── notifications/              # Push FCM
│   ├── admin/                      # Historial, export, retrain
│   └── ota/                        # OTA Android
├── src/main/resources/
│   ├── application.yml             # Config base
│   ├── application-docker.yml      # Sobreescritura para Docker
│   └── db/migration/               # Flyway (SQL)
├── src/test/
├── Dockerfile                      # Multi-stage
└── pom.xml
```

## Perfiles

| Perfil | Uso |
|---|---|
| (default) | Desarrollo local — Postgres/RabbitMQ en localhost |
| `docker` | Docker Compose — servicios en red interna |
| `test` | Tests — H2 en memoria |

Activar perfil: `--spring.profiles.active=docker` o variable `SPRING_PROFILES_ACTIVE=docker`.

## Base de datos (Flyway)

El esquema PostgreSQL lo gestiona **Flyway** al arrancar el backend Java — no hay scripts `db/init` en la raíz del repo.

```
backend/src/main/resources/db/migration/
├── V1__create_schema.sql      # Esquema completo (spec §5.1)
├── V2__seed_admin.sql         # IT_ADMIN inicial
├── V3__add_created_at_columns.sql
└── V4__fix_admin_password.sql
```

**Reset** (volumen corrupto o error `relation "users" does not exist` en V2):

```bash
make reset-db   # docker compose down -v
make up         # Postgres vacío → Flyway aplica V1→V4
```

Credenciales por defecto IT_ADMIN tras V4: `admin@sentilife.com` / `Admin1234!`

## Endpoints

Base path: `/api/v1`

- **Auth** — `POST /auth/register`, `/auth/login`, `/auth/refresh`
- **Personas** — `GET/POST /monitored-persons`, `POST /{id}/consent`
- **Telemetría** — `POST /telemetry/windows`, `GET /telemetry/status/{id}`
- **Alertas** — `GET /alerts`, `PATCH /alerts/{id}`
- **Admin** — `GET /admin/history`, `/admin/export`, `POST /admin/retrain`
- **OTA** — `GET /app/latest-version`

Detalle completo en `.specify/specs/factoria/2_spec.md` §6.

## Variables de entorno

| Variable | Descripción | Default |
|---|---|---|
| `SPRING_PROFILES_ACTIVE` | Perfil activo | (ninguno) |
| `POSTGRES_USER` | Usuario PostgreSQL | `fallsentinel` |
| `POSTGRES_PASSWORD` | Contraseña PostgreSQL | `fallsentinel123` |
| `POSTGRES_DB` | Base de datos | `fallsentinel` |
| `RABBITMQ_USER` | Usuario RabbitMQ | `guest` |
| `RABBITMQ_PASSWORD` | Contraseña RabbitMQ | `guest` |
| `JWT_SECRET` | Secreto para firmar JWT (min 32 chars) | dev-secret... |
| `INFERENCE_URL` | URL del servicio FastAPI | `http://api:8000` |

## Estado

**Fase 0** — estructura base creada, `/actuator/health` funcional.  
Pendiente: endpoints de negocio (Fase 2+), migraciones Flyway (SL-3).
