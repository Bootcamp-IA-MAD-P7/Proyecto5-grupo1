# 3. Plan — SentiLife

> **Metodología SDD:** tercer documento fundamental. Define el *cómo*: arquitectura, decisiones técnicas con sus alternativas, convenciones del repositorio, CI/CD y fases de ejecución. Consolida el contenido operativo de los antiguos `AGENTS.md` y `SDD.md` (ya eliminados). El desglose en tareas vive en `4_task.md`.

## 1. Arquitectura objetivo

```
┌─────────────────────────── Flutter (SentiLife app) ───────────────────────────┐
│  Perfil MONITORED        Perfil CAREGIVER           Perfil IT_ADMIN            │
│  sensores + consent      alertas + historial        historial global + export  │
└──────────────────────────────────┬─────────────────────────────────────────────┘
                                   │ HTTPS + JWT
                    ┌──────────────▼──────────────┐
                    │   Backend Java (Spring Boot)│
                    │  auth · roles · consent ·   │──── /actuator/prometheus
                    │  personas · alertas · OTA   │
                    └───┬──────────┬──────────┬───┘
              escribe   │          │ publica  │ consulta
        ┌───────────────▼─┐   ┌────▼─────┐  ┌─▼──────────────┐
        │    InfluxDB     │   │ RabbitMQ │  │  PostgreSQL    │
        │ sensor_window   │   │ telemetry│  │ users, alerts, │
        │ prediction      │   │ events   │  │ consents, ...  │
        └─────────────────┘   └────┬─────┘  └────────────────┘
                                   │ consume
                    ┌──────────────▼──────────────┐
                    │  Servicio de inferencia     │
                    │  FastAPI + model.pkl        │──── /metrics
                    │  (red interna, no expuesto) │
                    └─────────────────────────────┘

        Prometheus ──scrape──> Java, FastAPI, RabbitMQ, Postgres, InfluxDB
        Grafana ──lee──> Prometheus  (dashboard pipeline + salud)
```

### Responsabilidades

| Componente | Responsabilidad | NO hace |
|---|---|---|
| Flutter | Captura sensores, ventanas, UI de 3 perfiles, consentimiento, OTA | Lógica de clasificación en producción |
| Backend Java | Puerta de entrada única: auth JWT, roles, consentimiento, personas, alertas, historial, export, OTA | Inferencia ML |
| FastAPI (inferencia) | Preprocesado de ventana + predicción + versión de modelo | Negocio, auth de usuarios finales |
| RabbitMQ | Desacople telemetría → inferencia → alertas | Camino crítico si compromete latencia (ver §4.2) |
| PostgreSQL | Datos de negocio (spec §5.1) | Series temporales de alta frecuencia |
| InfluxDB | Telemetría cruda y predicciones (spec §5.2) | Datos identificativos |
| Prometheus + Grafana | Métricas y dashboards (RNF-01/02) | — |

---

## 2. Decisiones técnicas y alternativas (ADRs resumidos)

### ADR-01 — Backend de negocio en Java (Spring Boot), inferencia en Python

- **Decisión:** separar negocio (Java 21 + Spring Boot 3) e inferencia (FastAPI). 
- **Motivo:** el bootcamp exige servir el modelo con FastAPI; el equipo quiere un perfil profesional con Java para entrevistas. La separación es además la arquitectura correcta (el ciclo de vida del modelo es independiente del negocio).
- **Riesgo aceptado:** curva de aprendizaje. Mitigación: alcance de negocio mínimo, Spring Initializr, arquitectura por capas simple (controller → service → repository).

### ADR-02 — RabbitMQ para eventos, con fallback

- **Decisión:** RabbitMQ para `telemetry.window`, `fall.detected`, `alert.created`.
- **Motivo:** desacople, resiliencia, y perfil profesional del proyecto (mensajería asíncrona real).
- **Camino crítico:** para cumplir RNF-01 (< 5 s), la ingesta puede clasificar de forma **síncrona** (Java → HTTP → FastAPI) y usar la cola para lo no crítico (persistencia, notificación, feedback). Se decide en Fase 2 midiendo latencias.
- **Fallback documentado:** si RabbitMQ compromete el MVP, todo el flujo pasa a HTTP síncrono manteniendo los mismos contratos de spec §5.3; la cola se reintroduce después.
- **⚠ Decisión sprint 15/07 (`5_roadmap.md` §1):** camino crítico de predicción **síncrono HTTP** desde el día 1; RabbitMQ se usa solo para `alert.created` → notificador push.

### ADR-03 — InfluxDB para telemetría, con fallback

- **Decisión:** InfluxDB 2.x para `sensor_window` y `prediction` (predicción en segundos ⇒ series temporales de alta frecuencia).
- **Fallback:** tabla particionada en PostgreSQL (`telemetry_windows`) si InfluxDB añade demasiada complejidad. El contrato `telemetry_window_ref` (spec §5.1) es agnóstico al motor.
- **⚠ Decisión sprint 15/07 (`5_roadmap.md` §1):** **fallback activado** — telemetría en PostgreSQL para la entrega; InfluxDB pasa a evolución post-entrega.

### ADR-04 — JWT emitido y validado por el backend Java

- Spring Security + jjwt. Access token corto (15 min) + refresh (7 días). Roles como claim. BCrypt para contraseñas. El servicio FastAPI no valida JWT de usuarios: está en red interna y solo acepta tráfico del backend/worker.

### ADR-05 — Ventanas de telemetría

- Ventana deslizante de **2–3 s con solape del 50%** a la frecuencia de muestreo alineada con SisFall (200 Hz nativo; submuestreo del móvil documentado en el EDA). Los valores exactos se fijan en el EDA (T2 de `4_task.md`) y son **la misma definición en entrenamiento e inferencia** — divergencia aquí es el bug más caro del proyecto.

### ADR-06 — Migración desde el estado actual

El repo actual tiene FastAPI como API única (`Backend/api/main.py` con `classify()` por umbrales, OTA y Postgres). Plan de migración:

1. FastAPI queda **solo** como servicio de inferencia (`/predict`, `/health`, `/metrics`, `/model/info`).
2. OTA (`/app/*`) y la tabla `app_versions` migran al backend Java. **⚠ Sprint 15/07: migración pospuesta** — OTA se queda en FastAPI para la entrega (funciona y no aporta a la demo).
3. La lógica por umbrales `classify()` se reemplaza por `model.pkl` real (ML-04). El mock de desarrollo **solo** vive en Flutter (`api_service.dart`, `_useMock = true`) para trabajo offline — regla heredada: si cambia el contrato de predicción, actualizar backend y mock a la vez.

### ADR-07 — Notificaciones push con Firebase Cloud Messaging

- **Decisión:** las alertas al cuidador se entregan por **push FCM** (RF-27…RF-30), no solo por polling. El proyecto ya usa Firebase App Distribution en CI, así que el proyecto Firebase existe.
- **Flujo:** `alert.created` (RabbitMQ) → servicio notificador en Java (Firebase Admin SDK) → FCM → app cuidador (plugin `firebase_messaging`), con la app cerrada, en background o en foreground.
- **Contrato:** payload definido en spec §6.4; el token se registra vía `POST /devices/push-token`.
- **Fallback:** si FCM se atasca, el polling de `GET /alerts` (ya requerido por RF-15) mantiene la funcionalidad en demo; el push se marca como pendiente, no bloquea la fase.

### ADR-08 — Internacionalización (i18n)

- **Decisión:** Flutter con `flutter_localizations` + archivos **ARB** (`intl`), idiomas mínimos **es** y **en**. Todo texto de UI nuevo nace como clave ARB — prohibido hardcodear strings desde la Fase 2.
- Los textos legales (consentimiento, transparencia) se versionan por idioma: `policy_version = "1.0-es" / "1.0-en"` (spec §6.2).
- El backend devuelve claves/códigos de error estables (spec §6, campo `error`); la traducción del mensaje al usuario es responsabilidad del frontend.

### ADR-09 — Ciclo de reentrenamiento con datos reales (patrón proyecto4-grupo4)

- **Decisión:** replicar el patrón validado en `proyecto4-grupo4` (nivel Experto) adaptándolo a SentiLife:
  1. **Recogida de data real:** cada predicción que el usuario ve se persiste; el feedback del cuidador (confirmar/descartar) la convierte en muestra etiquetada (`feedback_labels` + ventana en InfluxDB).
  2. **Modal de transparencia** (RF-32): el usuario sabe que esa data se usa para reentrenar — mismo patrón de modal informativo del proyecto 4.
  3. **Job de reentrenamiento** con estado consultable (`POST /admin/retrain`, `GET /admin/retrain/status` — spec §6.6): fases `drift → training → reload`, decisión `promoted | candidate | discarded | skipped`.
  4. **Hot-reload del modelo:** la promoción no requiere reiniciar contenedores — FastAPI expone `POST /model/reload` interno y recarga el artefacto `ACTIVE` del registry.
  5. El candidato no promovido queda en **A/B** con ~20% del tráfico (ML-17).
- **Diferencia clave con el proyecto 4:** la métrica de decisión aquí es **recall de caídas** (no R²), con guardas de overfitting < 5% y validación por sujeto.

---

## 3. Estructura del repositorio (objetivo)

```
Proyecto5-grupo1/
├── Frontend/                    # App Flutter (SentiLife)
│   └── lib/                     # config/, models/, screens/ (3 perfiles),
│       ├── l10n/                #   ARB es/en (ADR-08)
│       └── services/            #   api, auth, sensors, push, update
├── backend-java/                # NUEVO — Spring Boot (negocio)
│   └── src/main/java/com/sentilife/
│       ├── auth/  users/  monitored/  consent/
│       ├── telemetry/  alerts/  notifications/  admin/  ota/
│       └── config/              # security, rabbit, influx, firebase
├── Backend/                     # Python — inferencia + ML
│   ├── api/                     # FastAPI: solo inferencia
│   ├── ml/                      # entrenamiento, registry/, artifacts/
│   ├── notebooks/               # EDA
│   ├── data/                    # raw/ · processed/ · feedback/ (constitución §5)
│   └── tests/
├── db/init/                     # SQL init PostgreSQL
├── observability/               # NUEVO — prometheus.yml, grafana/ (dashboards versionados)
├── docker-compose.yml           # stack completo local
├── docker-compose.prod.yml      # despliegue QA/EC2
├── docs/daily/                  # standups
├── .specify/                    # constitución + SDD (este documento)
└── .github/workflows/
```

### Convención: renombrar la app a SentiLife (heredada de AGENTS.md)

Cambiar el nombre visible exige tocar **todos** estos archivos (rutas relativas a `Frontend/`):

| Plataforma | Archivo | Campo |
|---|---|---|
| Android | `android/app/src/main/AndroidManifest.xml` | `android:label` |
| Web | `web/manifest.json` | `name`, `short_name`, `description` |
| Web | `web/index.html` | `<title>`, meta `description`, `apple-mobile-web-app-title` |
| Windows | `windows/CMakeLists.txt` | `BINARY_NAME` |
| Linux | `linux/CMakeLists.txt` | `BINARY_NAME`, `APPLICATION_ID` |
| macOS | `macos/Runner/Configs/AppInfo.xcconfig` | `PRODUCT_NAME`, `PRODUCT_BUNDLE_IDENTIFIER` |
| iOS | `ios/Runner/Info.plist` | `CFBundleDisplayName`, `CFBundleName` |
| General | `pubspec.yaml` | `description` |

El `package ID` (`com.jzelada.proyecto_flutter`) es independiente del nombre visible; cambiarlo es opcional y tiene sus propios campos por plataforma.

---

## 4. Plan de datasets y ML

| ID | Fuente | Estado | Uso |
|---|---|---|---|
| DS-01 | SisFall (Sucerquia et al., *Sensors* 2017) | **Activo** — 4.396 ensayos, 38 sujetos en repo | Entrenamiento y benchmark principal |
| DS-02 | MobiAct / MobiFall (BMI HMU) | Candidato — pendiente respuesta bmi@hmu.gr | Cross-dataset, generalización smartphone |
| DS-C | Combinado | Bloqueado hasta validar DS-02 | `processed/combined/` con unión documentada |

- **Plan B** si MobiAct no llega: solo SisFall (suficiente para Factoría F5, documentando el sesgo de edad), con UniMiB SHAR y FARSEEING como reservas académicas.
- **Reglas activas:** no confiar en el `model.pkl` actual; no regenerar `processed/` hasta ejecutar el pipeline definido en `4_task.md`; split **siempre por sujeto** (ML-07); criterios de fuentes en constitución §6.
- **Limitación conocida:** caídas de SisFall simuladas casi exclusivamente por adultos jóvenes → documentar en informe (`processed/sisfall/eda_output/analisis_sesgo.md`).

---

## 5. CI/CD y despliegue (consolidado del antiguo SDD §9)

### Flujo de ramas

**`dev`** = integración con tests (pre-check) → **`main`** = deploy completo a QA.

| Workflow | Disparo | Qué hace |
|---|---|---|
| `backend-ci.yml` | push/PR `dev` | pytest (Python) + `mvn test` (Java, cuando exista) + data layout + import check |
| `backend-ci.yml` | push `main` | tests → imágenes Docker Hub → deploy EC2 (DBs + colas + APIs + observabilidad) |
| `android.yml` | tras `backend-ci` OK en `main` | analyze → APK → GitHub Release → Firebase → registro OTA |

Orden en push a `main`: primero backend (infra + APIs); al terminar con éxito se lanza `android.yml` (APK → Firebase a testers → OTA en Postgres).

### Puertos en EC2 compartido (`34.235.130.33`)

| Servicio | Puerto host | Nota |
|---|---|---|
| API negocio (Java) | **8005** | Hereda el puerto público actual |
| Inferencia (FastAPI) | interno | No exponer |
| PostgreSQL (debug) | 5435 | API usa `db:5432` interno |
| Grafana | 3006 | Reutiliza el puerto reservado a frontend |
| Prometheus / RabbitMQ mgmt / InfluxDB | internos | Exponer solo si se necesita debug (Security Group) |

(El EC2 lo comparte Unicorn Valuation: 3005 / 8004 / 5434 — no tocar.)

### Secrets GitHub

| Secret | Workflows | Nota |
|---|---|---|
| `DOCKER_USERNAME`, `DOCKER_PASSWORD` | backend-ci | Docker Hub |
| `EC2_HOST`, `EC2_USER`, `EC2_SSH_KEY` | backend-ci, android | `EC2_HOST` a nivel **repositorio** (android no usa environment `production`) |
| `GOOGLE_SERVICES_JSON`, keystore, Firebase | android | Firma y distribución |
| `GH_PAT` | android | GitHub Release |
| `JWT_SECRET`, `INFLUX_TOKEN`, `RABBITMQ_PASSWORD` | backend-ci | Nuevos con el stack SentiLife |
| `FIREBASE_SERVICE_ACCOUNT` | backend-ci | Credencial Admin SDK para push FCM (ADR-07) |

Credenciales locales en `.env` (nunca commiteado); plantillas en `.env.example` / `.env.qa.example`.

### Premisa operativa (obligatoria)

**Cualquier persona que clone el repo debe poder levantar toda la infraestructura con un solo `docker compose up`** (Postgres, InfluxDB, RabbitMQ, backend Java, inferencia FastAPI, Prometheus, Grafana), y después arrancar la app con un script (`make flutter-local` / `scripts/run-flutter-local.sh`). Cada servicio nuevo que se añada al proyecto entra al compose en el mismo PR, con health check y variables en `.env.example`. Un compose que no levanta completo rompe el flujo de todo el equipo y se trata como bug bloqueante.

---

## 6. Organización del equipo y trabajo en paralelo

Equipo: **2 devs backend + 2 devs frontend**. El punto de encuentro son los **contratos de spec §6** — congelados por fase; cambios solo por PR al SDD acordado entre ambos lados.

### Workstreams

| Stream | Dev | Ámbito | Depende de |
|---|---|---|---|
| **BE-A** | Backend dev 1 | Java: auth JWT, usuarios, personas monitorizadas, consentimiento, OTA (spec §6.1, §6.2, §6.7) | Esqueleto Java (T0.4) |
| **BE-B** | Backend dev 2 | Java + Python: telemetría, integración inferencia, RabbitMQ, alertas, push FCM, admin/export (spec §6.3–§6.6, §6.8) | Esqueleto Java (T0.4); contrato de ventana (T1.2) |
| **FE-A** | Frontend dev 1 | Flutter: auth, i18n (ARB), perfil MONITORED (consentimiento, sensores, envío de ventanas), vinculación de dispositivo | Solo contratos (mock) |
| **FE-B** | Frontend dev 2 | Flutter: perfiles CAREGIVER e IT_ADMIN (formulario, alertas, push, historial), modal de transparencia | Solo contratos (mock) |

Transversal (rotativo o el primero que se libere): ML/EDA (Fase 1) y observabilidad.

### Reglas del paralelo

1. **Frontend nunca espera a backend:** todo se desarrolla contra el mock de Flutter (`_useMock`), que implementa exactamente los JSON de spec §6. Cuando el endpoint real existe, se apaga el mock y debe funcionar sin cambios.
2. **Backend nunca espera a frontend:** cada endpoint se valida con tests + Swagger/curl contra los mismos JSON.
3. Cada stream trabaja en su rama (`feat/be-a-auth`, `feat/fe-b-alerts`, …) → PR a `dev` con CI verde.
4. Al final de cada fase hay una **tarea de integración** explícita (mock off, end-to-end real, cronómetro de latencia) — está en `4_task.md` como `T<fase>.INT`.

---

## 7. Fases de ejecución

Cada fase termina con una demo funcional y una tarea de integración. El detalle está en `4_task.md`.

### Fase 0 — Fundaciones (SDD + estructura + compose)
Cerrar los 4 documentos SDD, renombrar app a SentiLife, **crear la estructura completa `backend-java/`** (no existe aún — tarea inicial T0.4), `observability/`, docker-compose ampliado (Java, RabbitMQ, InfluxDB, Prometheus, Grafana), i18n base en Flutter.
**Demo (T0.INT):** `docker compose up` en máquina limpia levanta todo el stack con health checks verdes + `make flutter-local` arranca la app.

### Fase 1 — Nivel Esencial (ML núcleo)
EDA SisFall completo, pipeline de ventanas, primer modelo con overfitting < 5%, `/predict` real en FastAPI, informe técnico v1, app enviando ventanas reales.
**Demo (T1.INT):** caída simulada con el móvil → predicción real del modelo.

### Fase 2 — Nivel Medio + perfiles + push
Ensembles + LOSO + Optuna; backend Java con auth JWT, roles, personas, consentimiento; alertas vía RabbitMQ + **notificaciones push FCM**; perfiles CAREGIVER e IT_ADMIN; modal de transparencia; feedback y export.
**Demo (T2.INT):** cuidador registra persona → caída → **push en el móvil del cuidador en < 5 s** → confirma/descarta → IT exporta dataset etiquetado.

### Fase 3 — Nivel Avanzado (producción)
Stack completo dockerizado y desplegado en EC2, InfluxDB en producción, tests unitarios Java + Python, Prometheus + Grafana con dashboard del pipeline, supresión GDPR end-to-end, i18n completo es/en.
**Demo (T3.INT):** despliegue automático desde `main`; demo de caída sobre QA con dashboard en vivo y app en ambos idiomas.

### Fase 4 — Nivel Experto (MLOps)
CNN 1D/LSTM vs. mejor ensemble, registro de modelos, reentrenamiento con datos reales y estado consultable (ADR-09), hot-reload, A/B testing, drift, auto-reemplazo condicionado.
**Demo (T4.INT):** IT lanza reentrenamiento desde la app con feedback real → decisión `promoted/candidate` visible → dos modelos en producción comparados en Grafana.

---

## 8. Riesgos del plan y contingencias

| Riesgo | Señal | Contingencia |
|---|---|---|
| Backend Java se atasca | Fase 2 sin auth funcional a mitad de fase | Reducir a auth + personas + alertas; historial/export via SQL directo |
| RabbitMQ/InfluxDB comen tiempo | Fase 0/2 alargadas | Activar fallbacks ADR-02/ADR-03 (HTTP síncrono + Postgres) |
| Push FCM se complica | Fase 2 avanzada sin push | Fallback ADR-07: polling de alertas para la demo, push como tarea pendiente |
| Latencia > 5 s | Medición Prometheus en Fase 1 | Clasificación síncrona en camino crítico, reducir ventana, revisar serialización |
| MobiAct no llega | Sin respuesta BMI al iniciar Fase 2 | Plan B §4 (solo SisFall + documentar sesgo) |
| Modelo no cumple overfitting < 5% | Informe Fase 1 | Regularización, más features estadísticas, revisar fuga por sujeto |
| Contratos divergen entre mock y backend | Integración de fase falla | El contrato de spec §6 gana; quien divergió corrige; añadir test de contrato |

---

## 9. Estado del documento

| Campo | Valor |
|---|---|
| Estado | Draft v0.2 — ADR-07/08/09 (push, i18n, reentrenamiento), workstreams paralelos y premisa de compose único |
| Autores | Equipo Grupo 1 |
| Última actualización | 08/07/2026 |
