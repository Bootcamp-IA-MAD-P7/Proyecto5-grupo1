# 4. Task — SentiLife

> **Metodología SDD:** cuarto documento fundamental. Backlog ejecutable derivado de `3_plan.md`, organizado por fases y por **workstreams paralelos** (2 devs backend + 2 devs frontend, `3_plan.md` §6). Cada tarea referencia los requisitos de `2_spec.md`. Marcar con `[x]` al completar; si una tarea cambia de alcance, actualizar primero spec/plan.
>
> El **orden de ejecución en el tiempo** y el backlog con IDs Jira (`SL-*`) están en `5_roadmap.md`; el mapeo es 1-a-1 con las tareas `T*` de este documento.
>
> **📌 ¿Task o Roadmap?** **`4_task.md` manda** — es el archivo de la verdad: qué hacer, en qué orden y cuándo está hecho (`[x]`). `5_roadmap.md` es el **espejo operativo** con IDs `SL-*` para commits/PRs y calendario; se actualiza **en el mismo commit** al marcar una tarea aquí. Si hay conflicto, gana este documento.
>
> **⛔ GATE DE PR (desde dom 12/07):** ningún PR se mergea sin: (1) esta tarea marcada `[x]`, (2) el SL correspondiente en ✅ en `5_roadmap.md §4`, (3) `make test` / `pytest` / `flutter test` verde. Ver checklist completo en `5_roadmap.md §0b`.

**Convenciones:**
- IDs: `T<fase>.<n>`. La tarea de integración de cada fase es `T<fase>.INT`.
- Columna **Stream**: `BE-A` (Java: auth/negocio), `BE-B` (Java+Python: telemetría/eventos/push), `FE-A` (Flutter: auth/monitored), `FE-B` (Flutter: caregiver/IT), `ML` (transversal), `ALL` (equipo).
- Dependencias entre paréntesis. Los streams sin dependencias entre sí se ejecutan **en paralelo**.

---

## Fase 0 — Fundaciones

### Comunes

- [x] **T0.1** `ALL` — Revisar y aprobar en equipo los 4 documentos SDD + constitución. **Congelar contratos de spec §6 para la fase.** *(bloqueante para todo)*
- [x] **T0.2** `FE-A` — Renombrar la app a **SentiLife** en todas las plataformas según tabla de `3_plan.md` §3.
- [x] **T0.3** `ALL` — Actualizar `README.md` raíz: nombre, arquitectura, referencia a los 4 documentos SDD.

### Estructura Java (no existe — tarea inicial de creación)

- [x] **T0.4** `BE-A` — **Crear desde cero la estructura `backend/`**: Spring Boot 3 + Java 21, paquetes `com.sentilife.{auth,users,monitored,consent,telemetry,alerts,notifications,admin,registry,config}`, perfil `application-docker.yml`, Dockerfile multi-stage, `/actuator/health`. *(ADR-01)*
- [x] **T0.5** `BE-B` — Flyway V1 (esquema spec §5.1), V2 (seed IT_ADMIN), V3 (created_at columns).

### Infraestructura y compose (premisa: un solo `docker compose up`)

- [x] **T0.6** `BE-B` — `docker-compose.yml` + `docker-compose.prod.yml` con backend, RabbitMQ, Prometheus, Grafana. Health checks y variables en `.env.example`. *(3_plan.md §5)*
- [x] **T0.7** `BE-B` — `observability/`: `prometheus.yml` (scrape Java actuator + FastAPI) + Grafana provisionado (datasource + dashboard pipeline). *(RF-24, RF-25)*
- [x] **T0.8** `BE-B` — Reducir FastAPI a servicio de inferencia: `/predict`, `/health`, `/metrics`, `/model/info`, `/model/reload`; `/app/*` marcado para migración. *(ADR-06)*
- [x] **T0.9** `FE-A` — Base i18n en Flutter: `flutter_localizations` + ARB `es`/`en`, selector de idioma, migrar strings existentes. Desde aquí, prohibido hardcodear textos. *(RF-31, ADR-08)*
- [x] **T0.10** `FE-B` — Actualizar el **mock de Flutter** para implementar exactamente los contratos de spec §6 (auth, personas, telemetría, alertas, admin) — es la herramienta que desacopla FE de BE. *(3_plan.md §6 regla 1)*
- [x] **T0.11** `ALL` — Actualizar `Makefile` y `scripts/verify-local.sh`: `make up` levanta el stack completo y verifica todos los health checks; `make flutter-local` arranca la app contra la infra local.

### Integración

- [ ] **T0.INT** `ALL` — En una máquina limpia: `git clone` → `cp .env.example .env` → `docker compose up` → todos los servicios sanos → `make flutter-local` muestra la app. Documentar cualquier fricción en README.

---

## Fase 1 — Nivel Esencial (ML núcleo) 🟢

### ML / datos

- [x] **T1.1** `ML` — EDA SisFall completo (`inference/notebooks/`): clases, histogramas X/Y/Z, correlación, sesgo edad/sexo, frecuencia de muestreo → `processed/sisfall/eda_output/`. *(ML-01)*
- [x] **T1.2** `ML` — Definir la **ventana** (tamaño, solape, frecuencia) y publicarla como contrato compartido entrenamiento ↔ inferencia ↔ app. Contrato v1.0.0 en `contracts/window_contract.json` + `contracts/window_contract.md`: 2.5 s, 50 Hz, 50% solape, 125 muestras/señal. *(ADR-05 — bloqueante T1.3, T1.7, T1.8)*
- [x] **T1.3** `ML` — Pipeline de features reproducible: regenerar `processed/sisfall/` con ventanas + features estadísticas. `sisfall_windows_features.csv.gz` + `feature_manifest.json`: 56.313 ventanas, 116 features, contrato SL-14. (T1.2)
- [x] **T1.4** `ML` — Baseline con split por sujeto (GroupKFold). *(ML-07)*
- [x] **T1.5** `ML` — Primer modelo candidato (RF/XGBoost) con overfitting < 5%, recall de caídas priorizado. *(ML-02, ML-03)*
- [x] **T1.6** `ML` — Informe técnico v1: métricas completas + ROC + confusión + feature importance + sesgo. *(ML-05)*

### Backend (paralelo a ML)

- [x] **T1.7** `BE-B` — Integrar modelo en FastAPI: carga `model.pkl`, preprocesado idéntico al entrenamiento, respuesta spec §6.8. Eliminar `classify()` por umbrales. *(ML-04, RF-13)* (T1.2, T1.5)
- [x] **T1.8** `BE-B` — Java: `POST /api/v1/telemetry/windows` + A/B testing → inferencia síncrona + métricas Prometheus. *(RF-12)*
- [x] **T1.9** `BE-A` — Java: `/api/v1/devices/pair`, `/devices/push-token` (spec §6.4).

### Frontend (paralelo, contra mock)

- [x] **T1.10** `FE-A` — Captura de sensores reales (acelerómetro/giroscopio) y construcción de ventanas según contrato T1.2; envío continuo con cola local si no hay red. *(RF-10, RF-11)*
- [x] **T1.11** `FE-A` — Pantalla MONITORED v1: estado de monitorización, última evaluación. *(RF-20)*

### Integración

- [x] **T1.INT** `ALL` — Mock off: app → Java → FastAPI → predicción real. Demo de caída simulada con el móvil; registrar latencia extremo a extremo medida. *(smoke: `make smoke-telemetry` — E2E 61–197 ms, inferencia 16 ms, modelo `baseline-v1`)*

---

## Fase 2 — Nivel Medio + perfiles + push 🟡

### ML

- [x] **T2.1** `ML` — Comparativa ensembles (RF vs. GB vs. XGBoost) con GroupKFold/LOSO. *(ML-06, ML-07)* — `ml/training/compare_ensembles.py` → `ml/artifacts/ensemble_comparison.json` (XGBoost LOSO **0.925**)
- [x] **T2.2** `ML` — Optuna sobre el mejor candidato; informe v2. *(ML-08)* — `ml/training/optuna_tune.py` → `ml/models/model_tuned.pkl` (test PR-AUC **0.916**) + `inference/docs/informe_tecnico_v2.md`

### Stream BE-A (auth y negocio)

- [x] **T2.3** `BE-A` — Auth completa: register, login, JWT con roles, BCrypt (spec §6.1). Tests `AuthServiceTest`. *(RF-01, RF-02, ADR-04)*
- [x] **T2.4** `BE-A` — CRUD personas monitorizadas + `MonitoredServiceTest` (spec §6.2). *(RF-03)*
- [x] **T2.5** `BE-A` — Consentimiento: entidad `Consent` + repo; filtro 403 en telemetría sin consentimiento. *(RF-05…RF-07)*
- [x] **T2.6** `BE-A` — Migrar OTA (`/app/*`) de FastAPI a Java (spec §6.7). *(ADR-06, RF-23)* — `OtaController.java` + `update_service.dart` ya apuntan a Java; T3.8 queda como verificación en dispositivo real.

### Stream BE-B (eventos, alertas, push)

- [x] **T2.7** `BE-B` — RabbitMQ: `RabbitConfig` exchanges/colas spec §5.3; path síncrono con telemetría. *(ADR-02, RF-14)*
- [x] **T2.8** `BE-B` — Alertas: `Alert`, `AlertController` (`GET /alerts`, `PATCH /{id}`), `feedback_labels`. *(RF-14, RF-16, RF-17)*
- [x] **T2.9** `BE-B` — **Push FCM**: `FirebaseConfig` + `NotificationService` + `AlertPushListener` consumiendo `alert.created`. *(RF-27…RF-30, ADR-07)*
- [x] **T2.10** `BE-B` — Admin: export dataset etiquetado → `data/feedback/` (script `ml/feedback/export_feedback_dataset.py`). *(RF-18, RF-19, ML-09)*

### Stream FE-A (monitored)

- [x] **T2.11** `FE-A` — Login real contra Java (SL-30) + navegación por rol (3 perfiles, AppShell). *(RF-20…RF-22)*
- [x] **T2.12** `FE-A` — Modal de **consentimiento** + flujo monitorizado. *(RF-05, RF-07)*
- [x] **T2.13** `FE-A` — Modal de **transparencia de datos**. *(RF-32)*

### Stream FE-B (caregiver + IT)

- [x] **T2.14** `FE-B` — Perfil CAREGIVER: formulario de registro de persona, lista con estado. *(RF-21)*
- [x] **T2.15** `FE-B` — Alertas en app: pantalla de detalle, confirmar/descartar con comentario. *(RF-15, RF-17)*
- [x] **T2.16** `FE-B` — **Push en Flutter**: `firebase_messaging`, registro de token en login, notificación en background/terminated, tap → `AlertDetailScreen`. *(RF-27…RF-29)* (T2.9)
- [x] **T2.17** `FE-B` — Perfil IT_ADMIN: historial global, export, usuarios. *(RF-22)*

### Cableado real (eliminar mocks — bloqueante para T1.INT y T2.INT)

> **Estado código lun 13:** `auth_service` y `api_service` ya usan backend real (`_useMock = false`). Los 5 servicios restantes siguen en mock. Ver `5_roadmap.md §0c`.

- [x] **T2.18** `FE-A`+`FE-B` — Apagar `_useMock` en `telemetry_service`, `monitored_service`, `alerts_service`, `devices_service`, `admin_service`; flag central en `AppConfig.useMock` (default `false`).
- [x] **T2.19** `FE-A`+`FE-B` — Inyectar `SessionManager.accessToken` en `_headers()` vía `api_headers.dart` (sustituir `Bearer mock-access-token`).
- [x] **T2.20** `FE-A` — Consentimiento real: `ConsentDialog` → `MonitoredService.acceptConsent()` (`POST /{id}/consent`); bloquear envío de ventanas si API devuelve 403.
- [x] **T2.21** `FE-A` — Flujo pairing dispositivo MONITORED: integrar `DevicesService.pair()` en pantalla antes de iniciar telemetría.
- [x] **T2.22** `FE-B` — Tras login CAREGIVER: obtener token FCM (`firebase_messaging`) + `DevicesService.registerPushToken()` (`POST /devices/push-token`). *(complementa T2.16)*

### Integración

- [x] **T2.INT** `ALL` — End-to-end real con cronómetro: cuidador registra persona → consentimiento → caída → **push en el móvil del cuidador < 5 s** → confirma → export IT contiene la muestra etiquetada. *(smoke: `make smoke-mvp` — alerta 291ms, push 325ms, export TRUE_FALL)*

---

## Fase 3 — Nivel Avanzado (producción) 🟠

- [x] **T3.1** `BE-B` — `docker-compose.prod.yml` con stack completo (Java, RabbitMQ, Prometheus, Grafana) y puertos EC2 de `3_plan.md` §5. *(ML-11)*
- [x] **T3.2** `BE-A` — CI: `ci.yml` con `mvn test`, imágenes a Docker Hub, secrets. *(RNF-07)*
- [ ] **T3.3** `BE-B` — Despliegue QA en EC2, Security Group (8005 público, resto interno). *(ML-13)* — **pendiente**
- [ ] **T3.4** `BE-A`+`BE-B` — Suite de tests completa: Java (auth, consentimiento, permisos por rol, alertas, contrato de errores) y Python (preprocesado, métricas, contrato `/predict`). *(ML-14)*
- [x] **T3.5** `BE-B` — Dashboard Grafana `sentilife-pipeline.json`: latencia, colas, errores, push. *(RF-25, RNF-01/02)*
- [ ] **T3.6** `BE-A` — Supresión GDPR end-to-end (Postgres + InfluxDB + tokens) con test. *(RF-08)*
- [ ] **T3.7** `FE-A`+`FE-B` — i18n completo es/en (incluidos textos legales versionados) + pulido de UX; revisar textos de push localizados por `locale` del token. *(RF-31)*
- [ ] **T3.8** `FE-B` — Verificar OTA end-to-end en dispositivo Android real (`update_service.dart` → Java `/app/*`). *(RF-23 — migración hecha en T2.6)*
- [ ] **T3.INT** `ALL` — Push a `main` → despliegue automático → demo de caída sobre QA con dashboard en vivo, app en ambos idiomas y latencia verificada (si > 5 s, contingencias de `3_plan.md` §8).

---

## Fase 4 — Nivel Experto (MLOps) 🔴

- [ ] **T4.1** `ML` — MobiAct (si llegó): validación, EDA comparativo, `processed/combined/`. Si no: cerrar Plan B documentado. *(3_plan.md §4)*
- [ ] **T4.2** `ML` — CNN 1D / LSTM sobre ventanas crudas vs. mejor ensemble, mismo split por sujeto. *(ML-15)*
- [x] **T4.3** `BE-B` — Registro de modelos: `ml/registry/` + modelos en `ml/models/` + FastAPI carga ACTIVE y expone `/model/reload` + `/model/registry`. *(ML-16, ADR-09)*
- [x] **T4.4** `BE-B`+`ML` — **Reentrenamiento**: `POST /api/v1/admin/retrain` + `GET /admin/retrain/status`; fases `DRIFT→TRAINING→EVALUATING→DECIDING`; decisión por recall + overfitting < 5%. *(RF-33, ML-19, ADR-09)*
- [ ] **T4.5** `FE-B` — Pantalla IT de MLOps: botón retrain, polling de fases, historial versiones. *(RF-33)* — **pendiente lun 13**
- [x] **T4.6** `BE-B` — A/B testing `ABTestingService`: 80/20% ACTIVE/CANDIDATE, métricas Prometheus por versión. *(ML-17)*
- [ ] **T4.7** `ML` — Monitoreo de data drift con panel y alerta en Grafana. *(ML-18)*
- [ ] **T4.8** `ALL` — Informe técnico final + presentación de negocio + presentación técnica. *(constitución §4)*
- [ ] **T4.INT** `ALL` — Demo experto: IT lanza reentrenamiento desde la app con feedback real acumulado → decisión visible (`promoted`/`candidate`) → dos modelos sirviendo tráfico comparados en Grafana → auto-reemplazo demostrado.

---

## Tablero de estado por nivel — actualizado lun 13/07 (verdad en código)

> **Regla de lectura:** un nivel solo está **CERRADO** cuando todas sus tareas `[x]` **y** su `.INT` están verificadas. El calendario de `5_roadmap.md §2` marca *objetivos planificados*, no estado real.

| Nivel bootcamp | Fases | Estado real | Qué falta para cerrarlo |
|---|---|---|---|
| 🟢 Esencial | Fase 0–1 | ⏳ **~95% · NO cerrado** | T0.INT |
| 🟡 Medio | 2 | ✅ **CERRADO** | — |
| 🟠 Avanzado | 3 | ⏳ **~50% · NO cerrado** | T3.3 EC2 · T3.4 tests · T3.6 GDPR · T3.7 i18n · T3.INT |
| 🔴 Experto | 4 | ⏳ **~40% · NO cerrado** | T4.2 CNN · T4.5 MLOps UI · T4.7 drift · T4.8 informe · T4.INT |

## Matriz rápida de paralelismo (Fase 2, la más cargada)

| | BE-A | BE-B | FE-A | FE-B |
|---|---|---|---|---|
| Semana 1 | T2.3 auth | T2.7 colas | T2.11 login | T2.14 caregiver |
| Semana 2 | T2.4/T2.5 personas+consent | T2.8/T2.9 alertas+push | T2.12/T2.13 modales | T2.15/T2.16 alertas+push |
| Cierre | T2.6 OTA ✅ · T2.18/19/20/21 ✅ | T2.10 admin | — | T2.17 IT ✅ · T2.22 push-token ✅ |
| Juntos | | | | **T2.INT** |

---

## Estado del documento

| Campo | Valor |
|---|---|
| Estado | v1.3 — lun 13: T2.INT MVP E2E (SL-43) — alerta 291ms, push 325ms, export IT |
| Autores | Equipo Grupo 1 |
| Última actualización | 13/07/2026 |
| Protocolo | Marcar `[x]` + actualizar `5_roadmap.md §0+§4` **en el mismo commit** del PR |
