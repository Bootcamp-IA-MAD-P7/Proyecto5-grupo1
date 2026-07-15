# 4. Task — SentiLife

> **Único archivo de verdad del backlog.** Derivado de `3_plan.md` / `2_spec.md`. Marcar `[x]` al completar; si cambia el alcance, actualizar primero spec/plan.
>
> Presentación Factoría: **jueves 16**. Contratos API: la corrección Fase 2c modifica `2_spec.md` §6 antes de tocar código.
>
> **⛔ GATE DE PR:** ningún merge a `dev`/`main` sin: (1) tarea `[x]` aquí, (2) `make test` / pytest / flutter test verde, (3) si cambia contrato §6 → OK de 1 dev por lado. Commits: `T3.4: …` o `SL-46: …`.

**Convenciones:**
- IDs: `T<fase>.<n>` (fuente). Opcional `SL-*` en commits (tabla abajo). Integración de fase = `T<fase>.INT`.
- Stream: `BE-A` · `BE-B` · `FE-A` · `FE-B` · `ML` · `ALL`.
- Dependencias entre paréntesis. Streams independientes → **en paralelo**.

---

## Tablero por nivel

> Un nivel solo está **CERRADO** cuando todas sus tareas `[x]` **y** su `.INT` están verificadas.

| Nivel bootcamp | Fases | Estado | Evidencia clave |
|---|---|---|---|
| 🟢 Esencial | 0–1 | ✅ **CERRADO** | T0.INT + T1.INT · `make up` + `make smoke-telemetry` |
| 🟡 Medio | 2 + 2b + 2c | ✅ **CERRADO** | T2.INT + T2c.INT · `make smoke-mvp` |
| 🟠 Avanzado | 3 | ✅ **CERRADO (9/9)** | T3.INT · `make smoke-qa-ec2` · acta `docs/daily/t3.8-t3int-20260714.md` |
| 🔴 Experto | 4 + 4d + 4e | ✅ **CERRADO** | T4.INT + T4d.INT + T4e · `make smoke-expert` · acta `docs/daily/t4dint-feedback-retrain-20260715.md` |
| 🟣 Post-demo | 5 | ✅ **CERRADO** | T5.1–T5.6 (push, export, Grafana, sensores, ayuda, umbral retrain) |

**Veredicto auditoría 15/07:** backlog Factoría **cerrado en código y smoke**. Único QA de campo pendiente (no bloquea merge): **10 min pantalla bloqueada en Xiaomi** — protocolo listo, ejecución programada jue 16 (`docs/daily/t2c11-android-background-qa-20260715.md`).

### Certeza técnica (grep + smoke)

| Check | Resultado |
|---|---|
| 0 mocks en `frontend/lib/` | ✅ |
| FE solo habla con Java `/api/v1/*` | ✅ |
| Java → FastAPI `/predict` síncrono | ✅ |
| Modelo real trackeado (`model.pkl`) | ✅ |
| Contrato ventana 125@50Hz alineado | ✅ |
| Consent + pairing + 2-de-3 + cooldown 60s | ✅ |
| Retrain consume feedback Postgres (`augmented_windows ≥ 1`) | ✅ |
| Gate IMU RF-40 antes de monitorizar | ✅ |
| Tests CI (15/07) | Java ✅ · pytest **54** passed · flutter **114** passed |

### Decisiones de alcance (no renegociar)

- InfluxDB → Postgres (ADR-03). RabbitMQ solo `alert.created` → push; predicción HTTP síncrona.
- MobiAct ✂ Factoría (CEMP). Dataset = SisFall.
- Registro público: selector obligatorio `CAREGIVER | MONITORED`; `IT_ADMIN` solo interno.
- `monitored_persons.user_id NOT NULL UNIQUE` — vinculación por email.
- Alertas: confirmación 2-de-3 y máximo una nueva alerta por persona cada 60 s.
- Background Android: foreground service; logout bloqueante con aislamiento por `userId`.

### QA — pantallas por rol

| Rol | Login seed | Pantalla raíz | Flujos conectados |
|---|---|---|---|
| `MONITORED` | `monitored@sentilife.com` / `Admin1234!` | `MonitoredScreen` | gate IMU → pair → consent → sensores → telemetría |
| `CAREGIVER` | `caregiver@sentilife.com` / `Admin1234!` | `CaregiverHomeScreen` | personas CRUD · alertas · feedback · push-token |
| `IT_ADMIN` | `admin@sentilife.com` / `Admin1234!` | `ItAdminScreen` | historial · export CSV · users · MLOps retrain |

APK QA: `make apk-qa` → `API_BASE_URL=http://100.52.221.179:8005`.

---

## Fase 0 — Fundaciones

### Comunes

- [x] **T0.1** `ALL` — Revisar y aprobar en equipo los 4 documentos SDD + constitución. **Congelar contratos de spec §6 para la fase.** *(bloqueante para todo)*
- [x] **T0.2** `FE-A` — Renombrar la app a **SentiLife** en todas las plataformas según tabla de `3_plan.md` §3.
- [x] **T0.3** `ALL` — Actualizar `README.md` raíz: nombre, arquitectura, referencia a los 4 documentos SDD.

### Estructura Java

- [x] **T0.4** `BE-A` — **Crear desde cero la estructura `backend/`**: Spring Boot 3 + Java 21, paquetes `com.sentilife.{auth,users,monitored,consent,telemetry,alerts,notifications,admin,registry,config}`, perfil `application-docker.yml`, Dockerfile multi-stage, `/actuator/health`. *(ADR-01)*
- [x] **T0.5** `BE-B` — Flyway V1 (esquema spec §5.1), V2 (seed IT_ADMIN), V3 (created_at columns).

### Infraestructura y compose

- [x] **T0.6** `BE-B` — `docker-compose.yml` + `docker-compose.prod.yml` con backend, RabbitMQ, Prometheus, Grafana. Health checks y variables en `.env.example`. *(3_plan.md §5)*
- [x] **T0.7** `BE-B` — `observability/`: `prometheus.yml` (scrape Java actuator + FastAPI) + Grafana provisionado (datasource + dashboard pipeline). *(RF-24, RF-25)*
- [x] **T0.8** `BE-B` — Reducir FastAPI a servicio de inferencia: `/predict`, `/health`, `/metrics`, `/model/info`, `/model/reload`; `/app/*` marcado para migración. *(ADR-06)*
- [x] **T0.9** `FE-A` — Base i18n en Flutter: `flutter_localizations` + ARB `es`/`en`, selector de idioma, migrar strings existentes. *(RF-31, ADR-08)*
- [x] **T0.10** `FE-B` — Actualizar el **mock de Flutter** para implementar exactamente los contratos de spec §6 — herramienta que desacopla FE de BE. *(3_plan.md §6 regla 1)*
- [x] **T0.11** `ALL` — Actualizar `Makefile` y `scripts/verify-local.sh`: `make up` levanta el stack completo y verifica todos los health checks; `make flutter-local` arranca la app contra la infra local.

### Integración

- [x] **T0.INT** `ALL` — Clone limpio → `make up` → 6/6 healthy → `make flutter-local`. README §Clone limpio.

---

## Fase 1 — Nivel Esencial (ML núcleo) 🟢

### ML / datos

- [x] **T1.1** `ML` — EDA SisFall completo → `processed/sisfall/eda_output/`. *(ML-01)*
- [x] **T1.2** `ML` — Contrato ventana v1.0.0: 2.5 s, 50 Hz, 50% solape, 125 muestras/señal. *(ADR-05)*
- [x] **T1.3** `ML` — Pipeline features reproducible: 56.313 ventanas, 116 features. *(T1.2)*
- [x] **T1.4** `ML` — Baseline con split por sujeto (GroupKFold). *(ML-07)*
- [x] **T1.5** `ML` — Primer modelo candidato (RF/XGBoost) overfitting < 5%, recall priorizado. *(ML-02, ML-03)*
- [x] **T1.6** `ML` — Informe técnico v1. *(ML-05)*

### Backend

- [x] **T1.7** `BE-B` — Integrar modelo en FastAPI: `model.pkl`, preprocesado idéntico, spec §6.8. *(ML-04, RF-13)* (T1.2, T1.5)
- [x] **T1.8** `BE-B` — Java: `POST /api/v1/telemetry/windows` + A/B testing → inferencia síncrona + métricas Prometheus. *(RF-12)*
- [x] **T1.9** `BE-A` — Java: `/api/v1/devices/pair`, `/devices/push-token` (spec §6.4).

### Frontend

- [x] **T1.10** `FE-A` — Captura sensores reales y ventanas según contrato T1.2; cola local offline. *(RF-10, RF-11)*
- [x] **T1.11** `FE-A` — Pantalla MONITORED v1: estado de monitorización, última evaluación. *(RF-20)*

### Integración

- [x] **T1.INT** `ALL` — Mock off: app → Java → FastAPI → predicción real. `make smoke-telemetry` PASS.

---

## Fase 2 — Nivel Medio + perfiles + push 🟡

### ML

- [x] **T2.1** `ML` — Comparativa ensembles (RF vs GB vs XGBoost) con GroupKFold/LOSO. *(ML-06, ML-07)*
- [x] **T2.2** `ML` — Optuna sobre el mejor candidato; informe v2. *(ML-08)*

### Stream BE-A

- [x] **T2.3** `BE-A` — Auth completa: register, login, JWT con roles, BCrypt (spec §6.1). *(RF-01, RF-02, ADR-04)*
- [x] **T2.4** `BE-A` — CRUD personas monitorizadas (spec §6.2). *(RF-03)*
- [x] **T2.5** `BE-A` — Consentimiento + filtro 403 en telemetría. *(RF-05…RF-07)*
- [x] **T2.6** `BE-A` — Migrar OTA (`/app/*`) de FastAPI a Java (spec §6.7). *(ADR-06, RF-23)*

### Stream BE-B

- [x] **T2.7** `BE-B` — RabbitMQ: exchanges/colas spec §5.3. *(ADR-02, RF-14)*
- [x] **T2.8** `BE-B` — Alertas + `feedback_labels`. *(RF-14, RF-16, RF-17)*
- [x] **T2.9** `BE-B` — Push FCM: `AlertPushListener` consumiendo `alert.created`. *(RF-27…RF-30, ADR-07)*
- [x] **T2.10** `BE-B` — Admin: export dataset etiquetado. *(RF-18, RF-19, ML-09)*

### Stream FE-A

- [x] **T2.11** `FE-A` — Login real + navegación por rol (AppShell). *(RF-20…RF-22)*
- [x] **T2.12** `FE-A` — Modal de consentimiento + flujo monitorizado. *(RF-05, RF-07)*
- [x] **T2.13** `FE-A` — Modal de transparencia de datos. *(RF-32)*

### Stream FE-B

- [x] **T2.14** `FE-B` — Perfil CAREGIVER: formulario + lista con estado. *(RF-21)*
- [x] **T2.15** `FE-B` — Alertas: detalle, confirmar/descartar con comentario. *(RF-15, RF-17)*
- [x] **T2.16** `FE-B` — Push en Flutter: FCM + tap → `AlertDetailScreen`. *(RF-27…RF-29)* (T2.9)
- [x] **T2.17** `FE-B` — Perfil IT_ADMIN: historial, export, usuarios. *(RF-22)*

### Cableado real (eliminar mocks)

- [x] **T2.18** `FE-A`+`FE-B` — Apagar mocks; `AppConfig.useMock` default `false`.
- [x] **T2.19** `FE-A`+`FE-B` — Inyectar `SessionManager.accessToken` en `_headers()` vía `api_headers.dart`.
- [x] **T2.20** `FE-A` — Consentimiento real + bloqueo 403.
- [x] **T2.21** `FE-A` — Flujo pairing dispositivo MONITORED.
- [x] **T2.22** `FE-B` — Token FCM + `registerPushToken()` tras login CAREGIVER.

### Integración

- [x] **T2.INT** `ALL` — E2E real: cuidador → consentimiento → caída → push < 5 s → feedback → export. `make smoke-mvp` PASS.

---

## Fase 2b — Auditoría de contrato FE↔BE

- [x] **T2.23** `FE-A`+`FE-B` — Paginación: `page` ?? `number` en list services.
- [x] **T2.24** `FE-B` — PATCH feedback: no reconstruir `Alert` desde respuesta.
- [x] **T2.25** `FE-B` — Historial: `alertId` sin `fallDetected`.
- [x] **T2.26** `FE-A` — `TelemetryService.getStatus()` parsea `lastPrediction`.
- [x] **T2.27** `BE-A` — `MonitoredResponse` embebe `lastPrediction` + `monitoringStatus` real.
- [x] **T2.28** `FE-A` — UI revocación consentimiento + self-revoke MONITORED.
- [x] **T2.29** `FE-A`+`FE-B` — `pairingCode` visible + pairing persistido en disco.
- [x] **T2.30** `FE-B` — `FirebaseBootstrap` no traga errores en silencio.
- [x] **T2.31** `FE-B` — UI activar/desactivar usuarios IT.
- [x] **T2.INT.b** `ALL` — Re-verificado E2E contra backend real. `make smoke-mvp` PASS.

---

## Fase 2c — Corrección de consistencia y ruido

### Identidad y contratos

- [x] **T2c.1** `FE-A` — Registro con selector `CAREGIVER | MONITORED`. *(RF-01)*
- [x] **T2c.2** `BE-A` — Vínculo obligatorio `monitoredUserEmail` + `user_id NOT NULL UNIQUE`. *(RF-03, ADR-10)*
- [x] **T2c.3** `FE-B` — Formulario CAREGIVER exige email MONITORED + errores 404/400/409. *(RF-03, RF-34)*

### Calidad de inferencia

- [x] **T2c.4** `ML`+`FE-A` — Fixtures móvil + diagnóstico paridad SisFall. *(ML-20, ADR-11)*
- [x] **T2c.5** `ML` — Reentreno mobile-aligned `xgboost-v1.1.0`, threshold 0.35, `adl_replay` 0 FP. *(ML-02…ML-05)*

### Agregación y control de spam

- [x] **T2c.6** `BE-B` — Regla 2-de-3 + cooldown 60 s en `AlertDecisionService`. *(RF-14, RF-15, ADR-11)*

### Sesión, background y aislamiento

- [x] **T2c.8** `FE-A` — `SessionRepository` unificado + secure storage. *(RF-35, ADR-12)*
- [x] **T2c.9** `FE-A` — `MonitoringCoordinator` + foreground service Android. *(RF-36, ADR-12)*
- [x] **T2c.10** `FE-A`+`FE-B`+`BE-B` — Logout bloqueante + aislamiento por `userId` + `recipientUserId` en push. *(RF-37…RF-39, ADR-12)*
- [x] **T2c.11** `BE-B` — JWT `DEVICE` en pairing + auth en telemetría. *(RF-39, Sec)*

### Regresión e integración

- [x] **T2c.7** `ALL` — Regresión completa contratos y producto. Acta `docs/daily/t2c7-t2cint-regression-20260714.md`.
- [x] **T2c.INT** `ALL` — Demo real ambos roles + sesión + ADL 0 FP + caída < 5 s. Acta misma fecha.
- [x] **T2c.QA** `QA` — Acta + protocolo Android 10 min pantalla bloqueada. Implementación verificada; **ejecución física 10 min pendiente jue 16**. `docs/daily/t2c11-android-background-qa-20260715.md`.

---

## Fase 3 — Nivel Avanzado (producción) 🟠

- [x] **T3.1** `BE-B` — `docker-compose.prod.yml` stack completo EC2. *(ML-11)*
- [x] **T3.2** `BE-A` — CI: `ci.yml` con 3 suites + imágenes Docker Hub. *(RNF-07)*
- [x] **T3.3** `BE-B` — Despliegue QA EC2 vía CI/CD. *(ML-13)*
- [x] **T3.4** `BE-A`+`BE-B` — Suite tests ampliada + `@PreAuthorize` roles. *(ML-14, RF-02)*
- [x] **T3.5** `BE-B` — Dashboard Grafana `sentilife-pipeline.json`. *(RF-25, RNF-01/02)*
- [x] **T3.6** `BE-A` — Supresión GDPR demostrada. *(RF-08)*
- [x] **T3.7** `FE-A`+`FE-B` — i18n completo es/en. *(RF-31)*
- [x] **T3.8** `FE-B` — OTA en dispositivo Android real (Xiaomi API 35). *(RF-23)*
- [x] **T3.INT** `ALL` — Demo QA EC2. `make smoke-qa-ec2` PASS. Acta `docs/daily/t3.8-t3int-20260714.md`.

---

## Fase 4 — Nivel Experto (MLOps) 🔴

- [x] **T4.2** `ML` — CNN 1D vs ensemble; ganador LOSO XGBoost. *(ML-15)*
- [x] **T4.3** `BE-B` — Registry + `/model/reload` + `/model/registry`. *(ML-16, ADR-09)*
- [x] **T4.4** `BE-B`+`ML` — Reentrenamiento real + auto-reemplazo. *(RF-33, ML-19)*
- [x] **T4.5** `FE-B` — Pantalla IT MLOps. *(RF-33)*
- [x] **T4.6** `BE-B` — A/B testing 80/20 ACTIVE/CANDIDATE. *(ML-17)*
- [x] **T4.7** `ML` — Data drift real + panel Grafana. *(ML-18)*
- [x] **T4.8** `ALL` — Informe técnico final + presentaciones negocio/técnica.
- [x] **T4.INT** `ALL` — Demo experto en vivo. `make smoke-expert` PASS. Acta `docs/daily/t4int-expert-demo-20260714.md`.

**Cortado:** T4.1 MobiAct ✂ CEMP — dataset Factoría = SisFall.

---

## Fase 4d — Feedback producción → retrain

- [x] **T4d.1** `BE-B` — `RetrainService` export DB → body `POST /train`. *(RF-33, ML-09)*
- [x] **T4d.2** `ML` — `POST /train` acepta `feedback_rows` en body. *(ML-19)*
- [x] **T4d.3** `BE-B`+`ML` — Tests + contrato spec §6.8.
- [x] **T4d.4** `FE-B` — UI MLOps: contador `feedback_records` / `augmented_windows`.
- [x] **T4d.INT** `ALL` — E2E feedback → retrain `augmented_windows=3`. Acta `docs/daily/t4dint-feedback-retrain-20260715.md`.

---

## Fase 4e — Gate sensores + deuda post-auditoría

- [x] **T4e.1** `FE-A` — Gate hardware MONITORED (RF-40): `SensorCapabilityService` + pantalla bloqueante.
- [x] **T4e.2** `ALL` — Contracts en prod: `COPY` en Dockerfile + volumen `docker-compose.prod.yml`.
- [x] **T4e.3** `BE-B` — `InferenceClient` fail-fast opcional en prod.
- [x] **T4e.4** `DOCS` — Spec alineada ADR-03 (InfluxDB → Postgres).

---

## Fase 5 — Post-demo UX y transparencia 🟣

- [x] **T5.1** `BE-B`+`FE-B` — Push completo: `MONITORING_STARTED/STOPPED`, `CONSENT_REVOKED`. *(RF-30)*
- [x] **T5.2** `FE-B`+`BE-B` — Export CSV autenticado con descarga real. *(RF-42)*
- [x] **T5.3** `BE-B`+`ALL` — Grafana EC2 accesible `:3006`. *(RF-43)*
- [x] **T5.4** `FE-A` — Pestaña Sensores en vivo con gráficos rolling. *(RF-41)*
- [x] **T5.5** `FE-B`+`BE-B` — Umbral mínimo feedback retrain + modales/criterios MLOps. *(RF-45)*
- [x] **T5.6** `FE-A`+`FE-B`+`FE-B` — Botón Ayuda con guía por perfil (MONITORED/CAREGIVER/IT). *(RF-44)*

---

## Estado del documento

| Campo | Valor |
|---|---|
| Estado | v2.21 — **T5.5/T5.6 UX explicativa** |
| Autores | Equipo Grupo 1 |
| Última actualización | 15/07/2026 — RF-44 ayuda · RF-45 umbral retrain |
| Protocolo | Marcar `[x]` aquí en el mismo commit de la tarea |
