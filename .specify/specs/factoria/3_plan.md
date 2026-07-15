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
| Flutter | Sesión segura, foreground service Android, captura sensores, ventanas, UI de 3 perfiles, consentimiento, OTA | Lógica de clasificación en producción |
| Backend Java | Puerta de entrada única: auth JWT, roles, vinculación de cuentas, consentimiento, agregación de predicciones, alertas, historial, export, OTA | Inferencia ML |
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
- **⚠ Decisión sprint (`4_task.md` · ADR-02):** camino crítico de predicción **síncrono HTTP**; RabbitMQ solo para `alert.created` → notificador push.

### ADR-03 — InfluxDB para telemetría, con fallback

- **Decisión:** InfluxDB 2.x para `sensor_window` y `prediction` (predicción en segundos ⇒ series temporales de alta frecuencia).
- **Fallback:** tabla particionada en PostgreSQL (`telemetry_windows`) si InfluxDB añade demasiada complejidad. El contrato `telemetry_window_ref` (spec §5.1) es agnóstico al motor.
- **⚠ Decisión sprint (`4_task.md` · ADR-03):** **fallback activado** — telemetría en PostgreSQL; InfluxDB post-Factoría / CEMP.

### ADR-04 — JWT emitido y validado por el backend Java

- Spring Security + jjwt. Access token corto (15 min) + refresh (7 días). Roles como claim. BCrypt para contraseñas. El servicio FastAPI no valida JWT de usuarios: está en red interna y solo acepta tráfico del backend/worker.

### ADR-05 — Ventanas de telemetría

- **Contrato SL-14/T1.2 cerrado:** la fuente versionada es `contracts/window_contract.json` y la guía humana vive en `contracts/window_contract.md`.
- Ventana deslizante de **2.5 s a 50 Hz**, **50% de solape**, salto de **1.25 s** y **125 muestras por señal obligatoria** (`accX/Y/Z`, `gyroX/Y/Z`).
- SisFall se remuestrea de **200 Hz nativo a 50 Hz** con interpolación lineal; Flutter debe emitir o normalizar las ventanas a la misma frecuencia antes de enviarlas.
- Las muestras viajan en unidades físicas (`m/s²` y `°/s`) y conservan la gravedad. Cualquier normalización pertenece al pipeline ML y debe ser idéntica en entrenamiento e inferencia.
- Una ventana sin señales obligatorias, con menos/más de 125 muestras sin remuestreo/recorte, o con `NaN`/infinitos es inválida. Divergir de este contrato entre entrenamiento, inferencia y app es el bug más caro del proyecto.

### ADR-06 — Migración desde el estado actual

El repo actual tiene FastAPI como API única (`Backend/api/main.py` con `classify()` por umbrales, OTA y Postgres). Plan de migración:

1. FastAPI queda **solo** como servicio de inferencia (`/predict`, `/health`, `/metrics`, `/model/info`).
2. OTA (`/app/*`) y la tabla `app_versions` migran al backend Java. **⚠ Sprint 15/07: migración pospuesta** — OTA se queda en FastAPI para la entrega (funciona y no aporta a la demo).
3. La lógica por umbrales `classify()` se reemplaza por `model.pkl` real (ML-04). Los mocks Flutter en `*_service.dart` quedan como **herramienta dev/test** (T0.10) — activables con `USE_MOCK=true` o `useMock: true` en tests. **Estado lun 13:** apagado global verificado (`AppConfig.useMock = false`; T2.18 ✅). Regla: si cambia el contrato, actualizar backend y mocks a la vez.

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
- **⚠ Hueco T4d (14/07):** el job `POST /admin/retrain` llama a `POST /train` sin pasar el export de Postgres. El feedback confirmado en app queda en DB y en `GET /admin/export`, pero no entra al entrenamiento hasta Fase 4d (`RetrainService` → body `feedback_rows`).

### ADR-10 — Identidad obligatoria de la persona monitorizada

- **Decisión:** el registro público obliga a elegir `CAREGIVER` o `MONITORED`. Una ficha en `monitored_persons` solo se crea al vincular por email una cuenta activa con rol `MONITORED`.
- **Integridad:** `monitored_persons.user_id` es `NOT NULL UNIQUE`. Flutter envía `monitoredUserEmail`; Java resuelve el usuario y nunca confía en un UUID aportado por el cliente.
- **Errores:** email inexistente `404`; cuenta inactiva o rol incorrecto `400`; cuenta ya vinculada `409`.
- **Migración:** se recreará la base de datos de desarrollo. No se implementa compatibilidad con fichas huérfanas anteriores.
- **Estado previo a vínculo:** una cuenta `MONITORED` sin ficha entra en `PENDING_LINK`; pairing, consentimiento y telemetría permanecen bloqueados.

### ADR-11 — Paridad ML y agregación anti-spam en backend

- **Diagnóstico antes de reentrenar:** capturar ventanas reales del móvil y comparar con SisFall: unidades (`m/s²`, `°/s`), gravedad, 50 Hz, 125 muestras, orden de features, finitud y distribución. Según la evidencia se corrige preprocesado, se recalibra el umbral o se reentrena.
- **Predicciones:** todas se persisten para auditoría y feedback, incluidas las que no generan alerta.
- **Confirmación:** una alerta requiere al menos 2 positivos entre las 3 predicciones más recientes de la persona.
- **Cooldown:** no se crea otra alerta para esa persona hasta transcurridos 60 segundos. Si la condición persiste, puede emitirse una nueva al terminar cada minuto.
- **Ubicación:** la política vive en Java, antes de RabbitMQ/FCM. Debe ejecutarse de forma atómica y consultar estado persistido para comportarse igual con varias instancias o tras reinicios.
- **Validación de campo:** replay reproducible de 10 minutos de actividad normal sin alertas; la primera alerta de una caída simulada conserva RNF-01 (< 5 s).

### ADR-12 — Sesión única, foreground service y cambio de cuenta seguro

- **Sesión:** eliminar la doble fuente `SessionManager`/`AuthSession`. Un único repositorio de sesión guarda el refresh token en `flutter_secure_storage`, restaura mediante `/auth/refresh` al arrancar y expone el usuario/token vigente a toda la app. La contraseña nunca se persiste.
- **Background:** el pipeline de sensores no pertenece a `MonitoredScreen`. Un `MonitoringCoordinator` controla un foreground service Android con notificación permanente; la captura continúa al minimizar o bloquear la pantalla y la UI solo observa su estado.
- **Credencial de telemetría:** el foreground service usa el device token persistido del pairing, no el access token del usuario. Java valida que sus claims coincidan con `monitoredPersonId` y `deviceId`.
- **Estado por cuenta:** pairing, consentimiento y preferencia de monitorización se guardan bajo namespace `userId`; cambiar de cuenta no comparte contexto.
- **Logout transaccional en cliente:** bloquear UI → `await stopMonitoring()` → cancelar cola/requests → `DELETE /devices/push-token/{deviceId}` si aplica → limpiar sesión segura → navegar a login. Un fallo de parada se muestra y no permite cambiar de cuenta silenciosamente.
- **Push:** el backend añade `recipientUserId`; foreground/background handlers consultan la sesión segura y descartan mensajes para otro usuario. El logout del cuidador desregistra su token FCM.
- **Límite de plataforma:** el foreground service es requisito Android. En web/escritorio/iOS del MVP la app informa que la captura se detiene si la plataforma no garantiza ejecución en background.

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
├── backend/                     # Java Spring Boot — esquema vía Flyway (db/migration/)
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
| DS-02 | MobiAct / MobiFall (BMI HMU) | ✂ **Fuera Factoría** → CEMP | No bloquea este sprint |
| DS-C | Combinado | ✂ Factoría | Solo si CEMP lo reactiva |

- **Factoría:** SisFall (DS-01) es el dataset activo; documentar sesgo de edad en informe. MobiAct no forma parte del alcance Factoría.
- **Reglas activas:** no confiar en el `model.pkl` actual; no regenerar `processed/` hasta ejecutar el pipeline definido en `4_task.md`; split **siempre por sujeto** (ML-07); criterios de fuentes en constitución §6.
- **Limitación conocida:** caídas de SisFall simuladas casi exclusivamente por adultos jóvenes → documentar en informe (`processed/sisfall/eda_output/analisis_sesgo.md`).

---

## 5. CI/CD y despliegue (consolidado del antiguo SDD §9)

### Flujo de ramas

**`dev`** = integración con tests (pre-check) → **`main`** = deploy completo a QA.

| Workflow | Disparo | Qué hace |
|---|---|---|
| `ci.yml` | push/PR `dev` | pytest (Python) + `mvn test` (Java, cuando exista) + data layout + import check |
| `ci.yml` | push `main` | tests → imágenes Docker Hub → deploy EC2 (DBs + colas + APIs + observabilidad) |
| `android.yml` | tras `backend-ci` OK en `main` | analyze → APK → GitHub Release → Firebase → registro OTA |

Orden en push a `main`: primero backend (infra + APIs); al terminar con éxito se lanza `android.yml` (APK → Firebase a testers → OTA en Postgres).

### Puertos en EC2 compartido (`100.52.221.179`)

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

1. **Frontend nunca espera a backend (Fase 0–1):** se desarrolló contra mocks Flutter que implementan exactamente los JSON de spec §6. **Estado lun 13:** mocks apagados (T2.18/T2.19 ✅); la app en runtime usa solo backend Java real. Los mocks siguen disponibles para offline/tests.
2. **Backend nunca espera a frontend:** cada endpoint se valida con tests + Swagger/curl contra los mismos JSON.
3. Cada stream trabaja en su rama (`feat/be-a-auth`, `feat/fe-b-alerts`, …) → PR a `dev` con CI verde.
4. Al final de cada fase hay una **tarea de integración** explícita (mock off, end-to-end real, cronómetro de latencia) — está en `4_task.md` como `T<fase>.INT`.

---

## 7. Fases de ejecución

Cada fase termina con una demo funcional y una tarea de integración. El detalle está en `4_task.md`.

### Fase 0 — Fundaciones (SDD + estructura + compose) — ✅ CERRADA
Cerrar los 4 documentos SDD, renombrar app a SentiLife, **crear la estructura completa `backend/`** (T0.4), `observability/`, docker-compose ampliado (Java, RabbitMQ, Prometheus, Grafana), i18n base en Flutter.
**Demo (T0.INT ✅):** clone limpio → `make up` → 6/6 healthy → `make flutter-local` / APK debug. Evidencia: SL-15, README §Clone limpio.

### Fase 1 — Nivel Esencial (ML núcleo) — ✅ CERRADA
EDA SisFall completo, pipeline de ventanas, primer modelo con overfitting < 5%, `/predict` real en FastAPI, informe técnico v1, app enviando ventanas reales.
**Demo (T1.INT ✅):** `make smoke-telemetry` — E2E 61–197 ms, inferencia 16 ms, modelo `baseline-v1`.

### Fase 2 — Nivel Medio + perfiles + push — ✅ CERRADA
Ensembles + LOSO + Optuna; backend Java con auth JWT, roles, personas, consentimiento; alertas vía RabbitMQ + **notificaciones push FCM**; perfiles CAREGIVER e IT_ADMIN; modal de transparencia; feedback y export; **mock-off completo** (T2.18–T2.22).
**Demo (T2.INT ✅):** `make smoke-mvp` — alerta 291 ms, push 325 ms, export IT `TRUE_FALL`.

### Fase 2c — Corrección de consistencia y ruido — 🔴 PRIORIDAD ACTUAL
Corregir el registro que fija siempre `CAREGIVER`, exigir vínculo por email a una cuenta `MONITORED`, recrear el esquema con `user_id NOT NULL UNIQUE`, diagnosticar la paridad móvil↔entrenamiento, añadir confirmación 2-de-3 con cooldown de 60 s y cerrar los fallos de sesión/background/cambio de cuenta.
**Demo (T2c.INT):** registrar ambos roles → vincular por email → restaurar sesión tras reinicio → 10 min de background con pantalla bloqueada → 10 min de ADL sin alertas → caída < 5 s y máximo una alerta/min → logout monitorizado → login cuidador sin telemetría ni alertas residuales.

### Fase 3 — Nivel Avanzado (producción)
Stack completo dockerizado y desplegado en EC2, InfluxDB en producción, tests unitarios Java + Python, Prometheus + Grafana con dashboard del pipeline, supresión GDPR end-to-end, i18n completo es/en.
**Demo (T3.INT):** despliegue automático desde `main`; demo de caída sobre QA con dashboard en vivo y app en ambos idiomas.

### Fase 4 — Nivel Experto (MLOps) — infra ✅ · RF-33 real pendiente
CNN 1D/LSTM vs. mejor ensemble, registro de modelos, reentrenamiento con estado consultable (ADR-09), hot-reload, A/B testing, drift, auto-reemplazo condicionado.
**Demo (T4.INT ✅):** IT lanza reentrenamiento → decisión visible → drift/A/B en Grafana.
**Pendiente (Fase 4d):** cablear feedback Postgres → `POST /train` (`augmented_windows >= 1`).

### Fase 4d — Feedback producción → retrain — 🔴 PRIORIDAD
Cerrar RF-33/ML-19: el retrain debe mezclar SisFall con ventanas etiquetadas que el cuidador confirmó/descartó en la app (sin CSV manual).
**Demo (T4d.INT):** `smoke-mvp` (feedback en DB) → `smoke-expert` → métricas con `augmented_windows >= 1`.

### Fase 4e — Gate sensores + deuda post-auditoría — 🟠 PRIORIDAD
RF-40: pantalla bloqueante si el móvil no tiene IMU obligatoria; no enviar telemetría inválida. Además: contracts en imagen prod, InferenceClient fail-fast opcional, alinear doc InfluxDB→Postgres (ADR-03), acta QA Android 10 min (T2c.11).

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
| Flutter fija un rol y no permite crear `MONITORED` | Todos los registros públicos son `CAREGIVER` | Selector obligatorio y widget/contract test del payload |
| Fichas sin cuenta real (`user_id` nulo) | Identidad y autorización inconsistentes | Resolución por email en Java + `NOT NULL UNIQUE` en PostgreSQL |
| Telemetría móvil fuera de distribución | El modelo clasifica ADL como caída | Diagnóstico de paridad previo a umbral/reentrenamiento + replay de campo |
| Una alerta por ventana positiva | Spam de historial, RabbitMQ y FCM | Agregación 2-de-3 y cooldown persistido de 60 s antes de publicar |
| Sesión duplicada y solo en memoria | Pérdida de login tras process death | Repositorio único + secure storage + refresh en bootstrap |
| Sensores ligados al ciclo de vida de una pantalla | Background deja de captar o logout deja tareas en vuelo | Foreground service + coordinador global + logout bloqueante |
| Pairing y push no aislados por cuenta | Alertas o contexto del usuario anterior | Namespace por `userId`, baja FCM y `recipientUserId` validado |

---

## 9. Estado de ejecución (sincronizado con `4_task.md` — 14/07)

| Nivel bootcamp | Fases | Estado | Evidencia clave |
|---|---|---|---|
| 🟢 Esencial | 0–1 | ✅ **CERRADO** | T0.INT + T1.INT · `make up` + `make smoke-telemetry` |
| 🟡 Medio | 2 + 2b + 2c | ✅ **CERRADO** | T2.INT + T2c.INT · `make smoke-mvp` |
| 🟠 Avanzado | 3 | ✅ **CERRADO (9/9)** | T3.INT · `make smoke-qa-ec2` |
| 🔴 Experto | 4 + **4d** + **4e** | ⏳ **infra 8/8 · RF-33 0/4 · RF-40 0/1** | T4.INT ✅ · **T4d + T4e pendientes** |

**Mocks Flutter:** eliminados; servicios solo contra Java real. **MobiAct:** fuera de alcance Factoría (CEMP).

---

## 10. Estado del documento

| Campo | Valor |
|---|---|
| Estado | v0.7 — Fases 4d + 4e (retrain + gate sensores) |
| Autores | Equipo Grupo 1 |
| Última actualización | 15/07/2026 |
