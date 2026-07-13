# 4. Task — SentiLife

> **Único archivo de verdad del backlog.** Derivado de `3_plan.md` / `2_spec.md`. Marcar `[x]` al completar; si cambia el alcance, actualizar primero spec/plan.
>
> Presentación Factoría: **jueves 16**. Contratos API: congelados en `2_spec.md` §6.
>
> **⛔ GATE DE PR:** ningún merge a `dev`/`main` sin: (1) tarea `[x]` aquí, (2) `make test` / pytest / flutter test verde, (3) si cambia contrato §6 → OK de 1 dev por lado. Commits: `T3.4: …` o `SL-46: …`.

**Convenciones:**
- IDs: `T<fase>.<n>` (fuente). Opcional `SL-*` en commits (tabla abajo). Integración de fase = `T<fase>.INT`.
- Stream: `BE-A` · `BE-B` · `FE-A` · `FE-B` · `ML` · `ALL`.
- Dependencias entre paréntesis. Streams independientes → **en paralelo**.

---

## Estado actual

> **Revalidado 13/07/2026 contra código** (no contra checkboxes). Objetivo: Esencial+Medio sin mocks, FE→Java→inference.

| Nivel | Estado | Progreso | Evidencia / pendiente |
|---|---|---|---|
| 🟢 Esencial | ✅ **CERRADO (revalidado)** | Fase 0–1 | Ver checklist abajo |
| 🟡 Medio | ✅ **CERRADO funcional** · ⚠ deuda residual | Fase 2 + 2b | Flujo producto OK; ver **Deuda residual pre-Fase 3** |
| 🟠 Avanzado | ⏳ | **4/9 (~44%)** | ✅ T3.1–3.3, T3.5 · 🔲 **T3.4 · T3.6 · T3.7 · T3.8 · T3.INT** |
| 🔴 Experto | ⏳ | **2/8 (~25%)** | ✅ T4.3, T4.6 · ✂ T4.1 CEMP · 🔲 **T4.2 · T4.4 · T4.5 · T4.7 · T4.8 · T4.INT** |

### Checklist Esencial + Medio (certeza)

| Check | Resultado | Evidencia |
|---|---|---|
| 0 mocks en `frontend/lib/` | ✅ | Grep: 0 hits `useMock` / `USE_MOCK` / `_mock` / `mock-access-token` |
| FE solo habla con Java | ✅ | Services → `AppConfig.apiBaseUrl` `/api/v1/*` · 0 llamadas a FastAPI |
| Java → FastAPI `/predict` | ✅ | `TelemetryService` → `InferenceClient` → HTTP sync |
| Modelo real en git | ✅ | `inference/ml/models/model.pkl` + `model_tuned.pkl` **trackeados** · registry ACTIVE XGBoost |
| Features alineadas contrato | ✅ | `window_contract.json` 125@50Hz · `features.py` · Flutter `SlidingWindowBuilder` |
| Consent + 403 telemetría | ✅ | BE + FE pipeline para en 403 |
| Pairing antes de monitorizar | ✅ | `MonitoredScreen` gate `isPaired` + consent |
| Alertas + feedback → export | ✅ | RabbitMQ `alert.created` · `feedback_labels` · `GET /admin/export` |
| Ensembles + Optuna + LOSO | ✅ | `ensemble_comparison.json` · `optuna_study.json` · informes v1/v2 |
| Compose 6 servicios | ✅ | db · rabbitmq · backend · api · prometheus · grafana |
| Smoke E2E documentados | ✅ | `make smoke-telemetry` · `make smoke-mvp` (correr local antes de demo) |

**Veredicto producto:** sí — **sin mocks**, **conectado FE ↔ Java ↔ inference con `model.pkl`**. Mañana puedes arrancar Fase 3/4 sobre esta base.

### Deuda residual (NO es Fase 3, pero no es “100% RF Medio”)

> No bloquean el flujo demo caída→alerta→export. Sí bloquean afirmar cumplimiento literal de cada RF. **Meter en T3.4 / hotfixes mañana AM si hay hueco.**

| ID | Hueco | Dónde | Acción sugerida |
|---|---|---|---|
| RF-02 / RF-22 | Comentarios dicen “IT_ADMIN only” pero **no hay `@PreAuthorize`** — cualquier JWT válido llega a `/admin/*` | `SecurityConfig` · `AdminController` | Añadir `hasRole('IT_ADMIN')` / CAREGIVER en endpoints (encaja en **T3.4**) |
| RF-30 | Push solo `FALL_ALERT` — no hay push de consent/monitor start/stop | `NotificationService` | Implementar o documentar como post-demo (spec Medio) |
| Sec | `/api/v1/telemetry/**` es `permitAll` (comentario “hasta device JWT”) | `SecurityConfig:55` | Cerrar cuando haya device JWT; consent sigue validándose en service |
| UX IT | Export muestra URL; no descarga autenticada con Bearer | `it_admin_screen.dart` | GET autenticado + save file |
| UX sesión | JWT solo en memoria · `refresh()` existe pero no se llama | `SessionManager` · `AuthService` | Persistencia + refresh (nice-to-have demo) |
| Docs | Task decía 82 FE tests · repo tiene **~69** `test(` | `frontend/test/` | Corregir número al correr `flutter test` |

**Decisiones de alcance (no renegociar cada día):**
- InfluxDB → Postgres (ADR-03). RabbitMQ solo `alert.created` → push; predicción HTTP síncrona.
- MobiAct ✂ Factoría (CEMP). Retrain stub **no** se marca ✅. i18n/OTA se mantienen en cola.
- Fallback `InferenceClient` (`inference-unavailable`): smoke **falla** si aparece — no silenciar en demo.

**Ruta crítica pendiente (solo Fase 3–4):**
```
T4.2 CNN + T4.7 drift → T4.4 retrain real → T4.5 MLOps UI → T4.INT → T4.8 (jue 16)
T3.4 tests (+ roles!) + T3.6 GDPR → T3.INT   |   CI/CD deploy ya ✅
```

**Arranque mañana (sin cuello de botella):**
1. `make up` → `make smoke-mvp` (prueba viva Java↔modelo).
2. Hotfix deuda residual roles (T3.4) si da tiempo AM.
3. Cola Experto: T4.2 → T4.7 → T4.4 → T4.5.

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

- [x] **T0.INT** `ALL` — En una máquina limpia: `git clone` → `cp .env.example .env` → `docker compose up` → todos los servicios sanos → `make flutter-local` muestra la app. Documentar cualquier fricción en README. *(verificado 13/07: clone → make up → verify 6/6 healthy; APK debug compila; fricciones en README §Clone limpio)*

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

### Frontend (paralelo — desarrollo inicial contra mock; cableado real en T2.18)

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

- [x] **T2.14** `FE-B` — Perfil CAREGIVER: formulario de registro de persona, lista con estado. *(RF-21)* — UI + CRUD + `monitoringStatus`/`lastPrediction` reales (backend embebe estado tras **T2.27**) + `pairingCode` visible (**T2.29**). *(verificado E2E lun 13)*
- [x] **T2.15** `FE-B` — Alertas en app: pantalla de detalle, confirmar/descartar con comentario. *(RF-15, RF-17)* — bug de contrato PATCH (`FeedbackResponse`≠`Alert`) corregido en **T2.24**; *(verificado E2E lun 13: `make smoke-mvp` PATCH feedback OK)*.
- [x] **T2.16** `FE-B` — **Push en Flutter**: `firebase_messaging`, registro de token en login, notificación en background/terminated, tap → `AlertDetailScreen`. *(RF-27…RF-29)* (T2.9)
- [x] **T2.17** `FE-B` — Perfil IT_ADMIN: historial global, export, usuarios. *(RF-22)* — bug de contrato historial (`alertId` sin `fallDetected`) corregido en **T2.25**; UI de activar/desactivar usuarios añadida en **T2.31**. *(verificado E2E lun 13)*

### Cableado real (eliminar mocks — bloqueante para T1.INT y T2.INT)

> **Estado código — ✅ MOCKS ELIMINADOS:** los servicios Flutter solo hablan con el backend Java real vía `http.Client` inyectable; ya no existe modo mock ni datos fake. Los tests usan `MockClient` de `package:http/testing`.

- [x] **T2.18** `FE-A`+`FE-B` — Apagar `_useMock` en `telemetry_service`, `monitored_service`, `alerts_service`, `devices_service`, `admin_service`; flag central en `AppConfig.useMock` (default `false`). *(verificado: ningún `useMock: true` en `frontend/lib/`)*
- [x] **T2.19** `FE-A`+`FE-B` — Inyectar `SessionManager.accessToken` en `_headers()` vía `api_headers.dart` (sustituir `Bearer mock-access-token`).
- [x] **T2.20** `FE-A` — Consentimiento real: `ConsentDialog` → `MonitoredService.acceptConsent()` (`POST /{id}/consent`); bloquear envío de ventanas si API devuelve 403.
- [x] **T2.21** `FE-A` — Flujo pairing dispositivo MONITORED: integrar `DevicesService.pair()` en pantalla antes de iniciar telemetría.
- [x] **T2.22** `FE-B` — Tras login CAREGIVER: obtener token FCM (`firebase_messaging`) + `DevicesService.registerPushToken()` (`POST /devices/push-token`). *(complementa T2.16)*

### Integración

- [x] **T2.INT** `ALL` — End-to-end real con cronómetro: cuidador registra persona → consentimiento → caída → **push en el móvil del cuidador < 5 s** → confirma → export IT contiene la muestra etiquetada. *(smoke: `make smoke-mvp` — alerta 291ms, push 325ms, export TRUE_FALL)*

---

## Fase 2b — Auditoría de contrato FE↔BE (lun 13) 🔴 CORRECCIÓN

> **Post-mortem honesto:** varias tareas de Fase 2 se marcaron `[x]` habiendo verificado solo la **UI contra mock**, no el **contrato real contra el backend Java**. Una auditoría del lun 13 encontró incompatibilidades que hacían fallar las pantallas contra el backend real. Estas tareas corrigen esos bugs y añaden lo que faltaba. **Regla reforzada:** una tarea FE que consume API no es `[x]` hasta verificar el JSON real (no el mock).

- [x] **T2.23** `FE-A`+`FE-B` — **Paginación**: todos los list services (`alerts`, `monitored`, `admin` history/users) leían `json['page']`, pero Spring `Page` serializa `number`. Ahora `page: json['page'] ?? json['number']`. *(afectaba SL-31/32/40 y lista de personas)*
- [x] **T2.24** `FE-B` — **SL-32**: `AlertsService.review()` parseaba `Alert.fromJson` sobre la respuesta del PATCH, pero el backend responde `{ alertId, status, feedbackLabelId }` (spec §6.5). Ahora no reconstruye `Alert`; devuelve `void`.
- [x] **T2.25** `FE-B` — **SL-40**: `HistoryEntry.fromJson` esperaba `id` + `fallDetected`; el backend envía `alertId` sin `fallDetected`. Ahora usa `alertId` y tolera la ausencia de `fallDetected`.
- [x] **T2.26** `FE-A` — **SL-31 (frontend)**: `TelemetryService.getStatus()` ignoraba `lastPrediction`; ahora lo parsea (formato plano de spec §6.3, sin `windowId` ni objeto `prediction` anidado).
- [x] **T2.27** `BE-A` — **SL-31 (backend)**: `MonitoredResponse` embebe `lastSeenAt` + `lastPrediction` (`{fallDetected,confidence,modelVersion,timestamp}`, spec §6.2/§6.3) y calcula `monitoringStatus` real (ACTIVE si consentimiento activo **y** última ventana < 5 min). `MonitoredService.toResponse` consulta `TelemetryWindowRepository` + 2 tests (`MonitoredServiceTest`). *(verificado E2E lun 13: `GET /monitored-persons/{id}` → `monitoringStatus=ACTIVE`, `lastPrediction.modelVersion=baseline-v1`, `timestamp` presente; alineado 1-a-1 con `LastPrediction.fromJson`)*
- [x] **T2.28** `FE-A` — **SL-37**: UI de **revocación de consentimiento** en pantalla MONITORED (botón → `MonitoredService.revokeConsent()`, detiene monitorización). Backend: nuevo `revokeConsentByMonitored()` + rama por rol en `DELETE /{id}/consent` para permitir **self-revoke** del MONITORED (antes solo CAREGIVER) + test. *(verificado E2E lun 13: DELETE por MONITORED → 200 `status=REVOKED`; `monitoringStatus` pasa a INACTIVE)*
- [x] **T2.29** `FE-A`+`FE-B` — **SL-24**: `pairingCode` visible en la tarjeta del cuidador; **pairing persistido** en disco (`MonitoredContextStore` usa `shared_preferences` con `load()`/`_persist()`, tolerante a Web/tests) → sobrevive al reinicio de la app.
- [x] **T2.30** `FE-B` — **SL-39**: `FirebaseBootstrap` deja de tragar el error en silencio: en Web sin `firebase_options` deshabilita push explícitamente (`pushDisabled=true`) y registra el motivo; en fallo de init marca `pushDisabled`. *(verificación en dispositivo Android físico con `google-services.json` queda como QA manual de campo — no automatizable en CI)*
- [x] **T2.31** `FE-B` — **SL-40**: UI para activar/desactivar usuarios (`SwitchListTile` en pestaña IT → `AdminService.setUserActive()` → `PATCH /admin/users/{id}`); modelo `User` incorpora `active` + test mock. *(verificado E2E lun 13: PATCH active=false/true → 200 con `active` actualizado)*
- [x] **T2.INT.b** `ALL` — **Re-verificado E2E contra backend real** (no mock) lun 13: `make up` (6/6 healthy) → `make smoke-mvp` **PASS** (registro→pairing→consentimiento→caída→alerta 331ms→push RabbitMQ 380ms→PATCH feedback→export IT con `TRUE_FALL`) + script de verificación de contratos nuevos (T2.27/T2.28/T2.31) **PASS**. Backend `mvn test` 23/23 ✅ · Flutter `flutter test` 82/82 ✅ · `flutter analyze` limpio.

---

## Fase 3 — Nivel Avanzado (producción) 🟠

### Hecho

- [x] **T3.1** `BE-B` — `docker-compose.prod.yml` con stack completo (Java, RabbitMQ, Prometheus, Grafana) y puertos EC2 de `3_plan.md` §5. *(ML-11)*
- [x] **T3.2** `BE-A` — CI: `ci.yml` con `mvn test` / pytest / flutter test, imágenes a Docker Hub, secrets. *(RNF-07)*
- [x] **T3.3** `BE-B` — Despliegue QA en EC2 vía CI/CD (`ci.yml` deploy on `main`, Security Group 8005 público, resto interno). *(ML-13)* — **CI/CD cerrado**
- [x] **T3.5** `BE-B` — Dashboard Grafana `sentilife-pipeline.json`: latencia, colas, errores, push. *(RF-25, RNF-01/02)*

### Pendiente (cerrar Avanzado)

- [ ] **T3.4** `BE-A`+`BE-B` — Suite de tests ampliada **+ enforcement de roles**. *(ML-14, RF-02)*
  - **Hoy:** ~23 unitarios Java + ~23 pytest. Sin MockMvc. **Sin `@PreAuthorize`** (cualquier JWT llega a `/admin`).
  - **Hacer:** (1) `hasRole('IT_ADMIN')` en `/admin/**` + retrain/registry; CAREGIVER en alerts/monitored según spec; (2) MockMvc: auth, consent 403, matriz roles, alertas PATCH, error JSON; (3) Python contrato `/predict`.
  - **CA:** caregiver JWT → 403 en `/admin`; IT_ADMIN → 200; `mvn test` + `pytest` verdes.

- [ ] **T3.6** `BE-A` — Supresión GDPR **demostrada**. *(RF-08)*
  - **Hoy:** cascade en `MonitoredService.delete()` (feedback → alerts → telemetry_windows → paired_devices → consents → person). Influx N/A (ADR-03 Postgres). Test actual solo `verify(mock)` — no toca BD.
  - **Hacer:** test de integración: crear persona + ventana + alerta + feedback → `DELETE /api/v1/monitored-persons/{id}` → assert `COUNT(*) = 0` en esas tablas.
  - **CA:** un test automatizado prueba el wipe; documentar en README que Influx no aplica.

- [ ] **T3.7** `FE-A`+`FE-B` — i18n completo es/en. *(RF-31)*
  - **Hoy:** ARB `app_es.arb` / `app_en.arb` (~118 keys, pares). Huecos: `login_screen.dart` hardcodeado ES; `update_service.dart` strings ES; push FCM en BE hardcodeado EN (no usa `PushToken.locale`); textos legales solo vía ARB + `policy_version = 1.0-{lang}` (sin docs legales versionados aparte).
  - **Hacer:** migrar login + OTA a ARB; localizar push por `locale` del token; revisar consentimiento/transparencia en ambos idiomas.
  - **CA:** app en `en` sin textos ES visibles en login/OTA/consent; push respeta locale.

- [ ] **T3.8** `FE-B` — OTA en dispositivo Android real. *(RF-23)*
  - **Hoy:** código listo (`update_service.dart` → Java `OtaController` `/app/*`; CI `android.yml` registra versión). Sin verificación en móvil físico ni test OTA.
  - **Hacer:** en Android físico: arrancar app → detectar versión → descargar APK → instalar. Anotar resultado en `docs/daily/`.
  - **CA:** flujo OTA ejecutado una vez en dispositivo real (o video corto).

- [ ] **T3.INT** `ALL` — Demo QA sobre EC2.
  - **Hacer:** merge/`main` → deploy automático → caída simulada contra `:8005` → alerta cuidador < 5 s → Grafana vivo → (ideal) app es/en.
  - **CA:** smoke QA documentado (latencias + URL health) + video o acta en `docs/daily/`.

---

## Fase 4 — Nivel Experto (MLOps) 🔴

### Hecho

- [x] **T4.3** `BE-B` — Registry: `ml/registry/` + `ml/models/` + FastAPI `/model/reload` + `/model/registry`. *(ML-16, ADR-09)*
- [x] **T4.6** `BE-B` — A/B testing `ABTestingService` 80/20 ACTIVE/CANDIDATE + métricas Prometheus. *(ML-17)*

### Cortado (no cuenta para Factoría)

- **T4.1** `ML` — ✂ **CORTADO** — MobiAct / Plan B → **CEMP**. Dataset Factoría = SisFall.

### Pendiente (cerrar Experto)

- [ ] **T4.2** `ML` — CNN 1D / LSTM vs mejor ensemble, mismo split por sujeto. *(ML-15)*
  - **Hoy:** solo sklearn/XGBoost (`train_model.py`, `compare_ensembles.py`, `optuna_tune.py`). Sin TF/Keras/PyTorch en `inference/requirements.txt`.
  - **Hacer:** script/notebook en `inference/ml/training/` (CNN1D o LSTM sobre ventanas crudas); GroupKFold/LOSO idéntico al ensemble; comparar recall/PR-AUC; documentar en informe.
  - **CA:** artefacto + métricas documentadas; overfitting < 5 pp; ningún subject_id en train y test.

- [ ] **T4.4** `BE-B`+`ML` — **Reentrenamiento real** + auto-reemplazo. *(RF-33, ML-19, ADR-09)*
  - **Hoy (stub — NO contar):** `RetrainService.java` hace `Thread.sleep` en drift y `callTrainingEndpoint()` lee `GET /model/info` con **recall=0.92 hardcodeado**. No entrena.
  - **Hacer:** endpoint/script real de train en FastAPI (o job que invoque `ml/training/…` con feedback de `data/feedback/`); devolver métricas reales; promover solo si recall ↑ y overfitting < 5%; hot-reload ACTIVE.
  - **CA:** `POST /admin/retrain` produce modelo nuevo medible; decisión `promoted|candidate|discarded` con números reales (no constantes).

- [ ] **T4.5** `FE-B` — Pantalla IT MLOps. *(RF-33)*
  - **Hoy:** `AdminService.startRetrain()` / `getRetrainStatus()` existen; `it_admin_screen.dart` solo tabs History / Export / Users. Posible mismatch JSON backend↔`RetrainJobStatus`.
  - **Hacer:** tab MLOps: botón retrain, polling de fases, historial/versión, mostrar decisión. Alinear DTO con `RetrainDtos`.
  - **CA:** IT_ADMIN lanza retrain desde la app y ve fases hasta completed.

- [ ] **T4.7** `ML` — Data drift **real** + panel Grafana. *(ML-18)*
  - **Hoy:** drift = `Thread.sleep(2000)` en `RetrainService`. Grafana `sentilife-pipeline.json` sin paneles de drift. Sin métrica Prometheus de drift.
  - **Hacer:** comparar distribución de features (p.ej. PSI/KS) train vs ventanas recientes; exponer métrica; panel + alerta en Grafana; cablear fase DRIFT del retrain a ese cálculo.
  - **CA:** panel Grafana con drift visible; valor cambia con datos; no hay sleep fingiendo drift.

- [ ] **T4.8** `ALL` — Informe técnico final + presentación negocio + presentación técnica. *(constitución §4)*
  - **Hoy:** solo `inference/docs/informe_tecnico_v1.md` y `v2.md`. Cero pptx/pdf de presentación.
  - **Hacer:** informe final (métricas + sesgo + Experto) + 2 decks. Entrega **jueves 16**.
  - **CA:** archivos en repo o `docs/` enlazados desde README.

- [ ] **T4.INT** `ALL` — Demo experto en vivo.
  - **Depende de:** T4.2, T4.4, T4.5, T4.7 (T4.6 ya ✅).
  - **Hacer:** IT lanza retrain desde app → decisión visible → A/B en Grafana → drift visible → (opcional) CNN mencionado en informe.
  - **CA:** guion de demo ejecutado una vez (local o QA) sin stubs.

---

## Cola para continuar (orden sugerido)

> Arrancar aquí mañana. Marcar `[x]` en la Fase 3/4 al cerrar. Paralelizar BE / ML / FE.

| # | Tarea | SL | Stream | Bloquea |
|---|---|---|---|---|
| 1 | **T4.2** CNN/LSTM | SL-53 | ML | T4.INT, informe |
| 2 | **T4.7** drift real + Grafana | SL-58 | ML | T4.4, T4.INT |
| 3 | **T4.4** retrain real (matar stub) | SL-55 | BE+ML | T4.5, T4.INT |
| 4 | **T4.5** MLOps UI | SL-56 | FE-B | T4.INT |
| 5 | **T3.4** MockMvc roles/alertas | SL-46 | BE | T3.INT / Avanzado |
| 6 | **T3.6** GDPR test integración | SL-48 | BE-A | Avanzado |
| 7 | **T3.7** i18n es/en | — | FE | T3.INT (idioma) |
| 8 | **T3.8** OTA Android real | — | FE-B | — |
| 9 | **T3.INT** demo QA | SL-51 | ALL | cierre Avanzado |
| 10 | **T4.8** presentaciones (jue 16) | SL-59 | ALL | entrega |
| 11 | **T4.INT** demo experto | SL-60 | ALL | cierre Experto |

Hechos relevantes (no reabrir): T3.1–3.3, T3.5 · T4.3, T4.6 · Fases 0–2 · T4.1 ✂ CEMP.

---

## Tablero por nivel

> Un nivel solo está **CERRADO** cuando todas sus tareas pendientes `[x]` **y** su `.INT` están verificadas.

| Nivel bootcamp | Fases | Estado | Pendiente explícito |
|---|---|---|---|
| 🟢 Esencial | 0–1 | ✅ **CERRADO** | — |
| 🟡 Medio | 2 + 2b | ✅ **CERRADO** | — |
| 🟠 Avanzado | 3 | ⏳ **4/9 (~44%)** | **T3.4** · **T3.6** · **T3.7** · **T3.8** · **T3.INT** |
| 🔴 Experto | 4 | ⏳ **2/8 (~25%)** | **T4.2** · **T4.4** · **T4.5** · **T4.7** · **T4.8** · **T4.INT** · T4.1 ✂ CEMP · (T4.3/T4.6 ✅) |

---

## Estado del documento

| Campo | Valor |
|---|---|
| Estado | v2.2 — revalidación Esencial+Medio (sin mocks, model.pkl en git) · deuda residual documentada · T3.4 incluye roles |
| Autores | Equipo Grupo 1 |
| Última actualización | 13/07/2026 |
| Protocolo | Marcar `[x]` aquí en el mismo commit de la tarea |