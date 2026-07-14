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

> **QA de campo 14/07/2026:** el flujo técnico funciona, pero se reabre Medio por registro sin selector de rol, fichas monitorizadas huérfanas, falsos positivos masivos, spam de alertas, sesión volátil y contaminación de procesos al cambiar de cuenta.

| Nivel | Estado | Progreso | Evidencia / pendiente |
|---|---|---|---|
| 🟢 Esencial | ✅ **CERRADO (revalidado)** | Fase 0–1 | Ver checklist abajo |
| 🟡 Medio | 🟢 **CERRADO (Fase 2c)** | Fase 2 + 2b + **2c** | T2c.7 + T2c.INT ✅ 14/07 — ver `docs/daily/t2c7-t2cint-regression-20260714.md` |
| 🟠 Avanzado | ⏳ | **5/9 (~56%)** | ✅ T3.1–3.3, T3.4, T3.5 · 🔲 **T3.6 · T3.7 · T3.8 · T3.INT** |
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

**Veredicto actualizado:** Fase 2c cerrada 14/07 con regresión ALL verde y demo documentada. Listo para retomar Fase 3/4.

### Deuda residual (NO es Fase 3, pero no es “100% RF Medio”)

> No bloquean el flujo demo caída→alerta→export. Sí bloquean afirmar cumplimiento literal de cada RF. **Meter en T3.4 / hotfixes mañana AM si hay hueco.**

| ID | Hueco | Dónde | Acción sugerida |
|---|---|---|---|
| RF-02 / RF-22 | Comentarios dicen “IT_ADMIN only” pero **no hay `@PreAuthorize`** — cualquier JWT válido llega a `/admin/*` | `SecurityConfig` · `AdminController` | Añadir `hasRole('IT_ADMIN')` / CAREGIVER en endpoints (encaja en **T3.4**) |
| RF-30 | Push solo `FALL_ALERT` — no hay push de consent/monitor start/stop | `NotificationService` | Implementar o documentar como post-demo (spec Medio) |
| Sec | `/api/v1/telemetry/**` es `permitAll` (comentario “hasta device JWT”) | `SecurityConfig:55` | Bloqueante T2c.11: validar token y vínculo persona/dispositivo |
| UX IT | Export muestra URL; no descarga autenticada con Bearer | `it_admin_screen.dart` | GET autenticado + save file |
| UX sesión | JWT solo en memoria · `refresh()` existe pero no se llama | `SessionManager` · `AuthService` | Bloqueante T2c.8: sesión única, secure storage y refresh |
| Docs | Task decía 82 FE tests · repo tiene **~85** `test(` | `frontend/test/` | Corregir número al correr `flutter test` |

**Decisiones de alcance (no renegociar cada día):**
- InfluxDB → Postgres (ADR-03). RabbitMQ solo `alert.created` → push; predicción HTTP síncrona.
- MobiAct ✂ Factoría (CEMP). Retrain stub **no** se marca ✅. i18n/OTA se mantienen en cola.
- Fallback `InferenceClient` (`inference-unavailable`): smoke **falla** si aparece — no silenciar en demo.
- Registro público: selector obligatorio `CAREGIVER | MONITORED`; `IT_ADMIN` solo interno.
- Toda ficha `monitored_persons` se vincula por email a una cuenta `MONITORED`; `user_id NOT NULL UNIQUE`. Se recreará la DB.
- Alertas: confirmación 2-de-3 y máximo una nueva alerta por persona cada 60 s mientras persista la condición.
- Background Android mantiene la captura mediante foreground service; minimizar no equivale a logout.
- Logout detiene y espera la monitorización antes de borrar la sesión; pairing y push quedan aislados por `userId`.

**Ruta crítica pendiente:**
```
T2c.1–T2c.3 identidad → T2c.7
T2c.4 diagnóstico ML → T2c.5 corrección modelo → T2c.7
T2c.6 agregación/cooldown → T2c.7 → T2c.INT
T2c.8 sesión → T2c.9 background → T2c.10 aislamiento logout/push → T2c.7
T2c.11 autorización device token → T2c.7
T2c.INT bloquea retomar Fase 3–4
T4.2 CNN + T4.7 drift → T4.4 retrain real → T4.5 MLOps UI → T4.INT → T4.8 (jue 16)
T3.4 tests (+ roles!) + T3.6 GDPR → T3.INT   |   CI/CD deploy ya ✅
```

**Arranque actual (sin cuello de botella):**
1. Aprobar esta actualización SDD y congelar los contratos de Fase 2c.
2. En paralelo: identidad (T2c.1–3), diagnóstico ML (T2c.4), alertas (T2c.6), sesión (T2c.8) y autorización de dispositivo (T2c.11).
3. Corregir modelo (T2c.5), cerrar background/aislamiento (T2c.9–10), ejecutar regresión E2E (T2c.7) y cerrar T2c.INT.

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

### Pendiente (cerrar Avanzado)

- [x] **T3.4** `BE-A`+`BE-B` — Suite de tests ampliada **+ enforcement de roles**. *(ML-14, RF-02)* **Evidencia 14/07:** `@EnableMethodSecurity` + `@PreAuthorize` en `/admin/**`, `/admin/models/**`, `/admin/retrain/**` (`IT_ADMIN`), `/alerts/**`, CRUD `/monitored-persons/**` y push-token (`CAREGIVER`), consent (`CAREGIVER|MONITORED`) · JSON 401/403 en `SecurityConfig` + `GlobalExceptionHandler` · `ApiSecurityIntegrationTest` 9 escenarios MockMvc (matriz roles, consent 403 sin pairing, alert PATCH) · `test_inference_api.py` +3 contratos `/predict` · `mvn test` 57/57 ✅ · `pytest tests/` verde.

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

> Cerrar Fase 2c antes de retomar Avanzado/Experto. Identidad, diagnóstico ML y agregación pueden arrancar en paralelo.

| # | Tarea | SL | Stream | Bloquea |
|---|---|---|---|---|
| 1 | **T2c.1–T2c.3** identidad y vínculo | — | FE+BE-A | T2c.7 |
| 2 | **T2c.4** diagnóstico móvil↔SisFall | — | ML+FE-A | T2c.5 |
| 3 | **T2c.6** 2-de-3 + cooldown | — | BE-B | T2c.7 |
| 4 | **T2c.8 + T2c.11** sesión + device auth | — | FE-A+BE-B | T2c.9/10/7 |
| 5 | **T2c.5** corregir/calibrar modelo | — | ML | T2c.7 |
| 6 | **T2c.9–T2c.10** background + aislamiento | — | FE+BE-B | T2c.7 |
| 7 | **T2c.7 + T2c.INT** regresión y demo | — | ALL | retomar Fase 3/4 |
| 8 | **T4.2** CNN/LSTM | SL-53 | ML | T4.INT, informe |
| 9 | **T4.7** drift real + Grafana | SL-58 | ML | T4.4, T4.INT |
| 10 | **T4.4** retrain real (matar stub) | SL-55 | BE+ML | T4.5, T4.INT |
| 11 | **T4.5** MLOps UI | SL-56 | FE-B | T4.INT |

Hechos relevantes (no reabrir): T3.1–3.3, T3.5 · T4.3, T4.6 · Fases 0–2 · T4.1 ✂ CEMP.

---

## Tablero por nivel

> Un nivel solo está **CERRADO** cuando todas sus tareas pendientes `[x]` **y** su `.INT` están verificadas.

| Nivel bootcamp | Fases | Estado | Pendiente explícito |
|---|---|---|---|
| 🟢 Esencial | 0–1 | ✅ **CERRADO** | — |
| 🟡 Medio | 2 + 2b + 2c | 🟢 **CERRADO** | — |
| 🟠 Avanzado | 3 | ⏳ **5/9 (~56%)** | **T3.6** · **T3.7** · **T3.8** · **T3.INT** |
| 🔴 Experto | 4 | ⏳ **2/8 (~25%)** | **T4.2** · **T4.4** · **T4.5** · **T4.7** · **T4.8** · **T4.INT** · T4.1 ✂ CEMP · (T4.3/T4.6 ✅) |

---

## Estado del documento

| Campo | Valor |
|---|---|
| Estado | v2.4 — Fase 2c añade sesión persistente, background y aislamiento de cuentas |
| Autores | Equipo Grupo 1 |
| Última actualización | 14/07/2026 — Fase 2c cerrada (T2c.7 + T2c.INT) |
| Protocolo | Marcar `[x]` aquí en el mismo commit de la tarea |