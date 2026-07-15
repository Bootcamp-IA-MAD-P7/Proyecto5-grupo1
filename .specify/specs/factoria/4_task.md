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

## Estado actual

> **QA de campo 14/07/2026:** Nivel Avanzado **CERRADO** (9/9). OTA verificado en dispositivo físico Xiaomi; T3.INT smoke EC2 PASS.

| Nivel | Estado | Progreso | Evidencia / pendiente |
|---|---|---|---|
| 🟢 Esencial | ✅ **CERRADO (revalidado)** | Fase 0–1 | Ver checklist abajo |
| 🟡 Medio | 🟢 **CERRADO (Fase 2c)** | Fase 2 + 2b + **2c** | T2c.7 + T2c.INT ✅ 14/07 |
| 🟠 Avanzado | ✅ **CERRADO** | **9/9** | T3.1–T3.8 + T3.INT ✅ — `docs/daily/t3.8-t3int-20260714.md` |
| 🔴 Experto | ⏳ | **8/8 infra · 4/4 T4d · 5/5 T4e** | Infra MLOps ✅ · **RF-33 Fase 4d ✅** · **RF-40 T4e.1 ✅** · T4e.2–T4e.4 ✅ · T2c.11 acta ✅ |

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
| Feedback → retrain automático | ✅ | `RetrainService` export DB → `POST /train` `feedback_rows` · `augmented_windows=3` (T4d.INT) |
| Ensembles + Optuna + LOSO | ✅ | `ensemble_comparison.json` · `optuna_study.json` · informes v1/v2 |
| Compose 6 servicios | ✅ | db · rabbitmq · backend · api · prometheus · grafana |
| Smoke E2E documentados | ✅ | `make smoke-telemetry` · `make smoke-mvp` (correr local antes de demo) |

**Veredicto actualizado (14/07):** Fase 2c cerrada · Fase 3 Avanzado **9/9 CERRADO** (T3.8 OTA físico Xiaomi + T3.INT smoke EC2) — acta `docs/daily/t3.8-t3int-20260714.md`.

### Deuda residual (post-demo, no bloquea Avanzado)

| ID | Hueco | Estado |
|---|---|---|
| RF-30 | Push solo `FALL_ALERT` — faltan `MONITORING_*` / `CONSENT_REVOKED` | **✅ T5.1** |
| UX IT | Export muestra URL; no descarga autenticada | **✅ T5.2** |
| Grafana EC2 | `:3006` en compose pero SG sin puerto público | **✅ T5.3** — Grafana accesible EC2 `:3006` |
| Sensores en vivo MONITORED | Sin gráficos locales de transparencia | **Fase 5 → T5.4** (RF-41) |
| **RF-33 / ML-19** | Retrain no consume feedback de Postgres automáticamente | **✅ Fase 4d cerrada 15/07** |
| **RF-40** | Sin gate de hardware: dispositivos sin IMU pueden intentar monitorizar | **✅ T4e.1** |
| Prod contracts | `docker-compose.prod.yml` / imagen inference sin `contracts/` | **✅ T4e.2** |
| InferenceClient | Fallback `inference-unavailable` silencioso salvo smoke-telemetry | **✅ T4e.3** fail-fast prod |
| Doc InfluxDB | `2_spec.md` aún cita InfluxDB; código usa Postgres (ADR-03) | **✅ T4e.4** |
| QA T2c.9 | Demo 10 min pantalla bloqueada Android sin acta | **✅ T2c.11** acta `docs/daily/t2c11-android-background-qa-20260715.md` |

**Decisiones de alcance (no renegociar cada día):**
- InfluxDB → Postgres (ADR-03). RabbitMQ solo `alert.created` → push; predicción HTTP síncrona.
- MobiAct ✂ Factoría (CEMP). Retrain stub **no** se marca ✅. i18n/OTA se mantienen en cola.
- Fallback `InferenceClient` (`inference-unavailable`): smoke **falla** si aparece — no silenciar en demo.
- Registro público: selector obligatorio `CAREGIVER | MONITORED`; `IT_ADMIN` solo interno.
- Toda ficha `monitored_persons` se vincula por email a una cuenta `MONITORED`; `user_id NOT NULL UNIQUE`. Se recreará la DB.
- Alertas: confirmación 2-de-3 y máximo una nueva alerta por persona cada 60 s mientras persista la condición.
- Background Android mantiene la captura mediante foreground service; minimizar no equivale a logout.
- Logout detiene y espera la monitorización antes de borrar la sesión; pairing y push quedan aislados por `userId`.

**Ruta crítica pendiente (sesión 15/07):**
```
T4e.1 (gate sensores)  — en paralelo con T4d.1 si dos streams
T4d.1 → T4d.2 → T4d.3 → T4d.INT  (cierre RF-33 real)
T4e.2 (contracts prod) — antes de push/redeploy EC2
```

### QA — pantallas por rol (revalidado)

| Rol | Login seed | Pantalla raíz | Flujos conectados a Java |
|---|---|---|---|
| `MONITORED` | `monitored@sentilife.com` / `Admin1234!` | `MonitoredScreen` | pair → consent → sensores → `POST /telemetry/windows` |
| `CAREGIVER` | `caregiver@sentilife.com` / `Admin1234!` | `CaregiverHomeScreen` | personas CRUD · tab alertas · PATCH feedback · push-token |
| `IT_ADMIN` | `admin@sentilife.com` / `Admin1234!` | `ItAdminScreen` | historial · export URL · users on/off |

Navegación: `AppShell` switch por `user.role` tras login real. **0 mocks** en `frontend/lib/`.
APK QA: `make apk-qa` → `API_BASE_URL=http://100.52.221.179:8005`. CORS abierto temporal (`CorsConfig`) — requiere redeploy backend en EC2.

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

## Fase 2c — Corrección de consistencia y ruido (mar 14) 🔴 PRIORIDAD

> La prueba de campo invalidó el cierre funcional de Medio: Flutter registra siempre `CAREGIVER`, el alta de una ficha no exige una cuenta `MONITORED` y cada ventana positiva genera una alerta. Esta fase se cierra antes de continuar Fase 3/4.

### Identidad y contratos

- [x] **T2c.1** `FE-A` — Registro Flutter con selector obligatorio `CAREGIVER | MONITORED`; nunca mostrar `IT_ADMIN`. Widget test verifica opciones públicas y request `MONITORED`. **Evidencia 14/07:** `flutter test` 73/73 ✅ · `flutter analyze` limpio. *(RF-01)*
- [x] **T2c.2** `BE-A` — Vínculo obligatorio implementado con `MonitoredRequest.monitoredUserEmail`, resolución normalizada en `users`, validación de cuenta activa/rol `MONITORED` y rechazo de duplicados. `V6__link_demo_monitored_user.sql` enlaza los seeds y aplica `user_id NOT NULL UNIQUE` + FK `ON DELETE RESTRICT`. **Evidencia 14/07:** `mvn test` 28/28 ✅ · volumen PostgreSQL recreado · Flyway V1→V6 ✅ · 1 ficha seed enlazada, 0 `user_id` nulos. Respuestas: inexistente `404`, rol/inactiva `400`, duplicada `409`. *(RF-03, ADR-10)* (T2c.1 independiente)
- [x] **T2c.3** `FE-B` — Formulario CAREGIVER exige email de la cuenta `MONITORED`, envía `monitoredUserEmail` y presenta los errores 404/400/409. Una cuenta `MONITORED` sin ficha muestra `PENDING_LINK`. **Evidencia 14/07:** `flutter test` 85/85 ✅ · `flutter analyze` limpio · widget tests `caregiver_home_screen_test.dart` (formulario + payload + errores) y `monitored_screen_test.dart` (PENDING_LINK) · service tests `MonitoredService.create/getMyProfile` en `services_http_test.dart` · backend `GET /monitored-persons/me` para RF-34 · `mvn test` 30/30 ✅. *(RF-03, RF-34)* (T2c.2 contrato)

### Calidad de inferencia

- [x] **T2c.4** `ML`+`FE-A` — Fixtures etiquetados en `inference/data/fixtures/mobile/` (4 ventanas: ADL móvil, spike caída, SisFall ADL/caida). Script reproducible `parity_diagnosis.py` + `generate_mobile_fixtures.py`. Informe causa raíz en `inference/docs/informe_paridad_movil_sisfall.md` (GRAVITY_AXIS + PEAK_SHAPE). **Evidencia 14/07:** `pytest tests/test_parity_diagnosis.py` 5/5 ✅ · paridad features.py↔training OK · `threshold_change_allowed=false`. *(ML-20, ADR-11)*
- [x] **T2c.5** `ML` — Corregir el pipeline, recalibrar el umbral o reentrenar según T2c.4. Versionar artefacto, threshold y métricas (recall, precision, F1, falsos positivos). Añadir replay automatizado de actividad normal. **Evidencia 14/07:** `pytest tests/` 34 passed, 1 skipped ✅ · `gravity_align.py` (Alineación a marco SisFall antes de features) · reentreno XGBoost `model.pkl` `xgboost-v1.1.0-mobile-aligned` · threshold **0.35** · test recall **0.89** · precision **0.74** · F1 **0.81** · PR-AUC **0.914** · `adl_replay` 3 ventanas **0 FP** · `ml/artifacts/t2c5_metrics.json` · `retrain_t2c5.py`. *(ML-02…ML-05, ML-20)* (T2c.4)

### Agregación y control de spam

- [x] **T2c.6** `BE-B` — Regla 2-de-3 + cooldown 60 s implementada en `AlertDecisionService` (lock pesimista en `monitored_persons`, consulta últimas 3 ventanas + última alerta, `Clock` inyectable). `TelemetryService` delega antes de RabbitMQ/FCM. **Evidencia 14/07:** `mvn test` 37/37 ✅ · `AlertDecisionServiceTest` (1/3, 2/3, cooldown <60s, ≥60s, lock) · `TelemetryServiceTest` (gate allow/block) · `smoke-mvp-e2e.sh` envía 2 ventanas caída. *(RF-14, RF-15, ADR-11)*

### Sesión, background y aislamiento de cuentas

- [x] **T2c.8** `FE-A` — `SessionRepository` unifica sesión (`ChangeNotifier` + `flutter_secure_storage` solo refresh token). Bootstrap en `main.dart` restaura vía `/auth/refresh`; `SessionManager`/`AuthSession` delegan al singleton. **Evidencia 14/07:** `flutter test` 90/90 ✅ · `session_repository_test.dart` (restore válido/inválido, login/logout, fuente única) · `services_http_test.dart` refresh · `flutter analyze` limpio. *(RF-35, ADR-12)*
- [x] **T2c.9** `FE-A` — `MonitoringCoordinator` extrae pipeline de `MonitoredScreen`; `MonitoringForegroundBridge` + `MonitoringForegroundService` Android (notificación permanente, `foregroundServiceType=health`). UI observa estado vía `ChangeNotifier`. **Evidencia 14/07:** `flutter test` 93/93 ✅ · `monitoring_coordinator_test.dart` (start/stop/notify/shutdown) · permisos manifest · QA manual 10 min Android pendiente documentar en demo. *(RF-36, ADR-12)* (T2c.8)
- [x] **T2c.10** `FE-A`+`FE-B`+`BE-B` — Logout bloqueante y aislamiento: esperar parada/cancelación de cola, almacenar contexto por `userId`, implementar `DELETE /devices/push-token/{deviceId}`, añadir `recipientUserId` al push y descartarlo si no coincide con la sesión restaurada. Tests de cambio `MONITORED → CAREGIVER` en el mismo dispositivo sin ventanas/alertas residuales. **Evidencia 14/07:** `mvn test` 48/48 ✅ · `flutter test` 100/100 ✅ · `LogoutService` + `MonitoringCoordinatorRegistry` (shutdown bloqueante) · `MonitoredContextStore` namespaced `ctx_{userId}_*` · `DELETE /api/v1/devices/push-token/{deviceId}` idempotente · `NotificationService` incluye `recipientUserId` · `PushNotificationService.shouldAcceptPayload` filtra por sesión · tests `logout_service_test.dart`, `account_isolation_test.dart`, `DeviceServiceTest`. *(RF-37…RF-39, ADR-12)* (T2c.8, T2c.9)
- [x] **T2c.11** `BE-B` — JWT `DEVICE` en pairing (`JwtService.generateDeviceToken`, hash SHA-256 en `paired_devices`). `DeviceAuthService` valida bearer en `POST /telemetry/windows` (401 ausente/inválido, 403 persona/dispositivo/pairing inactivo) antes de persistir. **Evidencia 14/07:** `mvn test` 46/46 ✅ · `DeviceAuthServiceTest` (8 escenarios) · `TelemetryServiceTest` gate auth · smoke scripts pasan `deviceToken`. *(RF-39, Sec)*

### Regresión completa

- [x] **T2c.7** `ALL` — Regresión de contratos y producto: ambos roles se registran; vínculos inválidos fallan; DB sin `user_id` nulo; sesión se restaura; background sigue capturando; logout elimina trabajo residual; push no cruza cuentas; telemetría, consentimiento, feedback y export siguen operativos. **Evidencia 14/07:** `make up` 6/6 healthy → `make smoke-mvp` PASS (alerta 432ms, push 472ms, export TRUE_FALL) → `make smoke-telemetry` PASS (E2E 122–146ms, inferencia 33ms) → `mvn test` 48/48 ✅ → `pytest tests/` 34 passed, 1 skipped ✅ → `flutter test` 100/100 ✅ · `flutter analyze` limpio → DB `user_id IS NULL` = 0 · link API 404/400/409 ✅ · `adl_replay` 0 FP · smoke scripts corregidos (`monitoredUserEmail` + pair antes de consent). Detalle: `docs/daily/t2c7-t2cint-regression-20260714.md`. (T2c.1–T2c.6, T2c.8–T2c.11)

### Integración

- [x] **T2c.INT** `ALL` — Demo real: registrar `MONITORED` y `CAREGIVER` → vincular por email → pairing/consentimiento → reiniciar app y restaurar sesión → 10 min con pantalla bloqueada capturando → 10 min de ADL con **0 alertas** → caída con primera alerta **< 5 s** y máximo una/min → logout monitorizado → login cuidador sin ventanas ni alertas residuales. **Evidencia 14/07:** `make smoke-mvp` + `make smoke-telemetry` E2E real (sin mocks) · alerta **432 ms** · push **472 ms** · `adl_replay` **0/3 FP** · acta `docs/daily/t2c7-t2cint-regression-20260714.md`. Pendiente: 10 min pantalla bloqueada en Android físico. (T2c.7)

---

## Fase 3 — Nivel Avanzado (producción) 🟠

### Hecho

- [x] **T3.1** `BE-B` — `docker-compose.prod.yml` con stack completo (Java, RabbitMQ, Prometheus, Grafana) y puertos EC2 de `3_plan.md` §5. *(ML-11)*
- [x] **T3.2** `BE-A` — CI: `ci.yml` con `mvn test` / pytest / flutter test, imágenes a Docker Hub, secrets. *(RNF-07)*
- [x] **T3.3** `BE-B` — Despliegue QA en EC2 vía CI/CD (`ci.yml` deploy on `main`, Security Group 8005 público, resto interno). *(ML-13)* — **CI/CD cerrado**
- [x] **T3.5** `BE-B` — Dashboard Grafana `sentilife-pipeline.json`: latencia, colas, errores, push. *(RF-25, RNF-01/02)*

### Hecho (Nivel Avanzado cerrado 14/07)

- [x] **T3.4** `BE-A`+`BE-B` — Suite de tests ampliada **+ enforcement de roles**. *(ML-14, RF-02)* **Evidencia 14/07:** `@EnableMethodSecurity` + `@PreAuthorize` en `/admin/**`, `/admin/models/**`, `/admin/retrain/**` (`IT_ADMIN`), `/alerts/**`, CRUD `/monitored-persons/**` y push-token (`CAREGIVER`), consent (`CAREGIVER|MONITORED`) · JSON 401/403 en `SecurityConfig` + `GlobalExceptionHandler` · `ApiSecurityIntegrationTest` 9 escenarios MockMvc (matriz roles, consent 403 sin pairing, alert PATCH) · `test_inference_api.py` +3 contratos `/predict` · `mvn test` 57/57 ✅ · `pytest tests/` verde.

- [x] **T3.6** `BE-A` — Supresión GDPR **demostrada**. *(RF-08)* **Evidencia 14/07:** `GdprSuppressionIntegrationTest` — seed persona + consent + paired_device + telemetry_window + alert + feedback → `DELETE /api/v1/monitored-persons/{id}` → `COUNT(*)=0` en las 6 tablas · cuentas `users` intactas · documentado en `backend/README.md` (InfluxDB N/A, ADR-03) · `mvn test` 58/58 ✅.

- [x] **T3.7** `FE-A`+`FE-B` — i18n completo es/en. *(RF-31)* **Evidencia 14/07:** `login_screen.dart` y `update_service.dart` migrados a ARB (`app_es.arb` / `app_en.arb`, +22 keys login/OTA) · `UpdateService.setLocale()` sincronizado con `MaterialApp.locale` · `FallAlertPushMessages` localiza FCM por `PushToken.locale` (es/en) · tests `login_screen_test.dart` (locale `en` sin textos ES) + `FallAlertPushMessagesTest` · `flutter test` 102/102 ✅ · `flutter analyze` limpio · `mvn test` 61/61 ✅.

- [x] **T3.8** `FE-B` — OTA en dispositivo Android real. *(RF-23)* **Evidencia 14/07:** Xiaomi `OJLNRO8PNFLNNBFA` (API 35) · v1 (`version_code=1`) instalado vía adb · diálogo **Actualización disponible** v1.0.100 · descarga APK (`adb reverse :8765`) · instalador MIUI aceptado · `dumpsys package` → **versionCode=100** / `1.0.100` · acta `docs/daily/t3.8-t3int-20260714.md`.

- [x] **T3.INT** `ALL` — Demo QA sobre EC2. **Evidencia 14/07:** `make smoke-qa-ec2` PASS · health UP · OTA `version_code=100` · MVP E2E remoto (sin mocks) alerta **755 ms** · export `TRUE_FALL` ✅ · Grafana `:3000` no accesible desde red pública (SG interno, documentado). Acta: `docs/daily/t3.8-t3int-20260714.md`.

---

## Fase 4 — Nivel Experto (MLOps) 🔴

### Hecho

- [x] **T4.3** `BE-B` — Registry: `ml/registry/` + `ml/models/` + FastAPI `/model/reload` + `/model/registry`. *(ML-16, ADR-09)*
- [x] **T4.6** `BE-B` — A/B testing `ABTestingService` 80/20 ACTIVE/CANDIDATE + métricas Prometheus. *(ML-17)*

### Cortado (no cuenta para Factoría)

- **T4.1** `ML` — ✂ **CORTADO** — MobiAct / Plan B → **CEMP**. Dataset Factoría = SisFall.

### Hecho

- [x] **T4.2** `ML` — CNN 1D vs mejor ensemble, mismo split por sujeto. *(ML-15)*
  - **Evidencia 14/07:** `ml/training/compare_cnn1d.py` + `raw_windows.py` · ventanas crudas `(125, 6)` SisFall · GroupShuffleSplit 70/15/15 + LOSO 38 sujetos · artefacto `ml/models/cnn1d-v1.0.0.keras` · métricas `ml/artifacts/cnn1d_comparison.json` · CNN test PR-AUC **0.862** recall **0.760** overfitting **1.36 pp** ✅ · XGBoost mismo split PR-AUC **0.891** LOSO **0.925** · ganador LOSO: **XGBoost** · informe `inference/docs/informe_tecnico_v3.md` · `pytest tests/` **39 passed**, 4 skipped ✅ · pipeline FastAPI sin cambios.

- [x] **T4.4** `BE-B`+`ML` — **Reentrenamiento real** + auto-reemplazo. *(RF-33, ML-19, ADR-09)*
  - **Evidencia 14/07:** `ml/training/retrain_feedback.py` · SisFall + feedback `data/feedback/` · `POST /train` FastAPI devuelve recall/precision/F1/overfitting reales · artefacto versionado `ml/models/retrain-*.pkl` · métricas `ml/artifacts/retrain_metrics.json` · registry CANDIDATE en `ml/registry/registry.json` · `RetrainService.callTrainingEndpoint()` → `POST /train` (sin stub) · promoción si recall ↑ vs ACTIVE y overfitting ≤ 5% · hot-reload vía `RegistryService.promote()` · `RetrainServiceTest` 5 escenarios (PROMOTED/CANDIDATE/DISCARDED/FAILED/POST /train) · `pytest tests/` **52 passed**, 4 skipped ✅ · `mvn test` **66/66** ✅.
  - **⚠ Deuda T4d (auditoría 14/07):** entrena sobre **SisFall + CSV estático** en `data/feedback/`. No lee automáticamente Postgres. Última ejecución: `augmented_windows=0`. Java `GET /admin/export` sí tiene ventanas etiquetadas — falta cablear al job. **RF-33 no escala sin Fase 4d.**

- [x] **T4.7** `ML` — Data drift **real** + panel Grafana. *(ML-18)*
  - **Evidencia 14/07:** `api/inference/drift.py` PSI vs SisFall baseline · buffer producción en `/predict` · `GET /drift` + `POST /drift/recompute` · Prometheus `feature_drift_psi`/`feature_drift_detected`/`feature_drift_samples` · Grafana dashboard v3 (gauge + timeseries + stat) · alerta `observability/grafana/provisioning/alerting/drift.yml` · `RetrainService` fase DRIFT → HTTP real (sin `Thread.sleep`) · baseline `ml/artifacts/drift_baseline.json` · `pytest tests/` **45 passed**, 4 skipped ✅ · `mvn test` **61/61** ✅.

### Hecho (infra MLOps — cerrado 14/07)

- [x] **T4.5** `FE-B` — Pantalla IT MLOps. *(RF-33)*
  - **Evidencia 14/07:** tab MLOps en `it_admin_screen.dart` (4ª pestaña) · botón retrain + polling 2s · fases/decisión/métricas visibles · `RetrainJobStatus.fromJson` alineado con `RetrainDtos` backend (`phase`, `decision`, `metrics`) · i18n es/en (+16 keys MLOps) · `retrain_status_test.dart` + contrato HTTP actualizado · `flutter test` **104/104** ✅ · `mvn test` **66/66** ✅.

- [x] **T4.8** `ALL` — Informe técnico final + presentación negocio + presentación técnica. *(constitución §4)*
  - **Evidencia 14/07:** `inference/docs/informe_tecnico_final.md` (consolidado v1→v3 + MLOps + sesgo) · `docs/presentaciones/presentacion_negocio.md` · `docs/presentaciones/presentacion_tecnica.md` (Marp) · README §Entregables Factoría · artefactos `ml/artifacts/*.json` referenciados · entrega jue 16.

- [x] **T4.INT** `ALL` — Demo experto en vivo.
  - **Evidencia 14/07:** `make smoke-expert` PASS (local, sin stubs) · IT `POST /admin/retrain` → decisión **DISCARDED** recall=0.890 overfitting=9.9% (20.3s) · drift PSI=0.0 samples=3 · Prometheus `ab_active=3` · `feature_drift_psi=0.0` · acta `docs/daily/t4int-expert-demo-20260714.md` · fix Docker `contracts` mount + `window_contract.py` fallback · `mvn test` **66/66** ✅ · `pytest tests/` **52/52** (4 skipped) ✅.

---

## Fase 4d — Feedback producción → retrain (post-auditoría MLOps) 🔴 PRIORIDAD

> **Post-mortem 14/07:** T4.4/T4.INT demuestran el pipeline MLOps (drift, train, decisión, UI, Grafana), pero el retrain **no consume** los datos que la app recoge. El cuidador confirma/descarta → Postgres (`feedback_labels` + `telemetry_windows.samples_json`). Java exporta vía `GET /admin/export`. FastAPI solo lee CSVs locales sin `samples_json` → `augmented_windows=0`. Sin Fase 4d, RF-33/ML-19 no cumplen la promesa de “reentrenar con datos reales recogidos”.

- [x] **T4d.1** `BE-B` — **Cablear export DB → retrain.** `RetrainService` invoca `AdminService.exportLabelledDataset()` antes de `POST /train` y envía las filas etiquetadas (ventana IMU + `TRUE_FALL`/`FALSE_ALARM`) en el body HTTP. Sin paso manual de CSV. *(RF-33, ML-09, ADR-09)* (T4.4)
- [x] **T4d.2** `ML` — **`POST /train` acepta feedback en body.** Contrato §6.8: `{ "feedback_rows": [{ "samples": {...}, "label": "..." }] }`. `retrain_feedback.py` prioriza payload HTTP > CSV en `data/feedback/` > solo SisFall. Métricas incluyen `augmented_windows` real. *(ML-19)* (T4d.1)
- [x] **T4d.3** `BE-B`+`ML` — **Tests + contrato.** `RetrainServiceTest` verifica que export DB se serializa al body; `test_retrain_feedback.py` con payload HTTP y `augmented_windows >= 1`; actualizar `2_spec.md` §6.8. *(RF-33)*
- [x] **T4d.4** `FE-B` — **UI MLOps: contador feedback.** Pestaña MLOps muestra `feedback_records` y `augmented_windows` del último job (desde `RetrainDtos.metrics`). i18n es/en. *(RF-33)* (T4d.1)

### Integración

- [x] **T4d.INT** `ALL` — **E2E feedback → retrain.** `make smoke-mvp` (PATCH feedback `TRUE_FALL` en DB) → `make smoke-expert` → `retrain_metrics.json` con `feedback.augmented_windows >= 1`. Acta en `docs/daily/`. *(T4d.1–T4d.3)*

---

## Fase 4e — Gate sensores + deuda post-auditoría (15/07) 🟠 PRIORIDAD

> **Post-auditoría 14/07:** huecos que no bloquean Avanzado pero sí calidad de demo/producción y RF-40.

- [x] **T4e.1** `FE-A` — **Gate hardware MONITORED (RF-40).** Antes de pairing/consent/monitorizar, comprobar disponibilidad de acelerómetro y giroscopio (`sensors_plus` o probe con timeout). Si falta alguno obligatorio: pantalla bloqueante dedicada (no `MonitoredScreen` operativa), sin botón “Iniciar monitoreo”, sin `MonitoringCoordinator.start()`, sin `POST /telemetry/windows`. i18n es/en. Tests: unit `SensorCapabilityService` + widget pantalla bloqueada. *(RF-10, RF-11, RF-40)* (T2c.9)
- [x] **T4e.2** `ALL` — **Contracts en prod/EC2.** Incluir `contracts/window_contract.json` en imagen inference (`inference/Dockerfile` `COPY` desde contexto build) **o** volumen en `docker-compose.prod.yml` (como dev). Verificar `make smoke-expert` con compose prod. *(T4.4, T4.INT)*
- [x] **T4e.3** `BE-B` — **InferenceClient fail-fast opcional.** Propiedad `sentilife.inference.fail-fast=true`: si FastAPI no responde, propagar error HTTP 503 en lugar de `inference-unavailable` silencioso. Mantener fallback solo en dev. Test `InferenceClientTest`. *(checklist Esencial)*
- [x] **T4e.4** `DOCS` — **Alinear spec con ADR-03.** Sustituir referencias InfluxDB por Postgres/`telemetry_windows` en `2_spec.md` §2.3, §5.2, CA-04, CA-18. Sin cambio de código. *(ADR-03)*
- [x] **T2c.11** `QA` — **Acta demo Android 10 min.** Documentar en `docs/daily/`: pantalla bloqueada, notificación foreground, telemetría continua ≥10 min. Dispositivo físico. *(T2c.9 — QA manual pendiente)*

---

## Cola activa (sesión 15/07 — hoy)

| # | Tarea | Stream | Prioridad | Bloquea |
|---|---|---|---|---|
| 1 | **T4e.1** Gate sensores MONITORED | FE-A | 🔴 Alta | RF-40 · data basura |
| 2 | **T4d.1** Java export → POST /train body | BE-B | 🔴 Alta | RF-33 real |
| 3 | **T4d.2** FastAPI `feedback_rows` | ML | 🔴 Alta | T4d.1 |
| 4 | **T4e.2** Contracts prod Docker/EC2 | ALL | 🟠 Media | redeploy EC2 |
| 5 | **T4d.3** tests + spec §6.8 | BE-B+ML | 🟠 Media | T4d.2 |
| 6 | **T4d.4** UI contador feedback MLOps | FE-B | 🟡 Baja | T4d.1 |
| 7 | **T4d.INT** smoke `augmented_windows ≥ 1` | ALL | 🔴 Alta | Cierre Experto real |
| 8 | **T4e.3** InferenceClient fail-fast | BE-B | 🟡 Baja | — |
| 9 | **T4e.4** Doc InfluxDB → Postgres | DOCS | 🟡 Baja | — |
| 10 | **T2c.11** Acta QA Android 10 min | QA | 🟡 Baja | — |

**Orden sugerido implementación:** T4e.1 → T4d.1 → T4d.2 → T4d.3 → T4e.2 → T4d.4 → T4d.INT (T4e.3/T4e.4/T2c.11 en paralelo o al cierre).

Hecho (no reabrir): Fases 0–2c · **Fase 3 Avanzado (9/9)** · **Fase 4 infra (8/8)** · T4.2–T4.7 · T4.INT · T4.8 · T4.1 ✂ CEMP.

---

## Fase 5 — Post-demo UX y transparencia (15/07) 🟣

> No bloquea presentación Factoría jue 16. Contratos en `2_spec.md` v0.9 (RF-41…RF-43).

- [x] **T5.1** `BE-B`+`FE-B` — **RF-30 completo.** Publicar eventos RabbitMQ + FCM al iniciar/detener monitorización y revocar consentimiento (`MONITORING_STARTED`, `MONITORING_STOPPED`, `CONSENT_REVOKED`). Prioridad baja en FCM. Flutter: parsear tipos en `PushNotificationService` (sin navegar a alerta). *(RF-30)*
- [x] **T5.2** `FE-B`+`BE-B` — **Export CSV autenticado (RF-42).** `AdminController` añade `Content-Disposition`; Flutter descarga con `http` + Bearer y guarda/comparte archivo. Eliminar `SelectableText` URL. Test widget + MockMvc header. *(RF-19, RF-42)*
- [x] **T5.3** `BE-B`+`ALL` — **Grafana EC2 accesible (RF-43).** Puerto `3006` expuesto en servidor QA (`100.52.221.179:3006`). *(RF-22, RF-25)*
- [ ] **T5.4** `FE-A` — **Pestaña Sensores en vivo (RF-41).** `MonitoredScreen` con `TabBar`: Estado | Sensores. Suscribirse al stream de `SensorCaptureService` / `MonitoringCoordinator`; gráficos rolling ~30 s (`accX/Y/Z`, `gyroX/Y/Z`) con `fl_chart` o similar. Visible solo si monitorización activa; i18n es/en; widget test. Sin cambio de contrato API (datos locales). *(RF-32, RF-41)*

**Esfuerzo estimado:** T5.4 ~4 h · T5.2 ~2 h · T5.1 ~3 h · T5.3 ~30 min infra.

---

## Cola activa (histórico Fase 4 — infra MLOps, cerrada 14/07)

---

## Tablero por nivel

> Un nivel solo está **CERRADO** cuando todas sus tareas pendientes `[x]` **y** su `.INT` están verificadas.

| Nivel bootcamp | Fases | Estado | Pendiente explícito |
|---|---|---|---|
| 🟢 Esencial | 0–1 | ✅ **CERRADO** | — |
| 🟡 Medio | 2 + 2b + 2c | 🟢 **CERRADO** | — |
| 🟠 Avanzado | 3 | ✅ **CERRADO (9/9)** | — |
| 🔴 Experto | 4 + **4d** + **4e** | ✅ **CERRADO** | T4.1 ✂ CEMP |

---

## Estado del documento

| Campo | Valor |
|---|---|
| Estado | v2.19 — Fase 5: T5.1+T5.3 ✅ · pendiente T5.2 T5.4 |
| Autores | Equipo Grupo 1 |
| Última actualización | 15/07/2026 — Grafana EC2 :3006 verificado en servidor |
| Protocolo | Marcar `[x]` aquí en el mismo commit de la tarea |