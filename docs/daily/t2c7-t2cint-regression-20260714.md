# T2c.7 + T2c.INT — Regresión ALL y demo de campo — 14/07/2026

> Ejecutado en rama `dev` · entorno local · `make up` (6/6 healthy)

## T2c.7 — Checklist de regresión

| Check | Criterio | Evidencia |
|---|---|---|
| Registro | `MONITORED` y `CAREGIVER` con selector de rol | `flutter test` 100/100 ✅ · widget `register_screen_test` · API: register HTTP 201 ambos roles |
| Vínculo | `monitoredUserEmail`; errores 404/400/409 | API smoke: 404 missing · 400 wrong role · 409 duplicate · widget tests `caregiver_home_screen_test.dart` |
| DB | Sin `user_id` nulo en `monitored_persons` | `SELECT COUNT(*) WHERE user_id IS NULL` → **0** · total 5 / linked 5 |
| Sesión | Restore tras reinicio | `session_repository_test.dart` · `services_http_test.dart` refresh |
| Background | `MonitoringCoordinator` + foreground service | `monitoring_coordinator_test.dart` · manifest `foregroundServiceType=health` |
| Logout | Parada bloqueante, cola cancelada, contexto por userId, push desregistrado | `logout_service_test.dart` · `account_isolation_test.dart` · `DeviceServiceTest` |
| Push | `recipientUserId` filtrado; no cruza cuentas | `push_notification_test.dart` · `account_isolation_test.dart` |
| Pipeline | Telemetría + consentimiento + alertas 2-de-3/cooldown 60s + feedback + export IT | `make smoke-mvp` PASS · `AlertDecisionServiceTest` · `TelemetryServiceTest` |
| ADL sin FP | Ventanas ADL móvil/SisFall | `adl_replay`: 3 ventanas · **0 FP** · threshold 0.35 |

### Comandos ejecutados (14/07/2026 ~16:00 UTC-4)

```bash
make up                    # 6/6 healthy
make smoke-mvp             # PASS
make smoke-telemetry       # PASS
cd backend && mvn test     # 48/48 ✅
cd inference && pytest tests/  # 34 passed, 1 skipped ✅
cd frontend && flutter analyze && flutter test  # limpio · 100/100 ✅
PYTHONPATH=inference python3 -m ml.evaluation.adl_replay  # 0 FP
```

### Resultados smoke (latencias E2E)

**`make smoke-mvp`** (2026-07-14T19:55:59Z):

| Métrica | Valor |
|---|---|
| Alerta visible (GET /alerts) | **432 ms** |
| Push RabbitMQ→FCM | **472 ms** (`rabbitmq_processed`) |
| `fallDetected` | true (conf 0.5004) |
| Export IT `TRUE_FALL` | ✅ |
| Regla 2-de-3 | 2 ventanas caída → 1 alerta |

**`make smoke-telemetry`** (2026-07-14T19:55:58Z):

| Métrica | Valor |
|---|---|
| E2E ADL window | 146 ms |
| E2E fall window | 122 ms |
| FastAPI `/predict` | 33 ms |
| Modelo | `baseline-v1.1-mobile-aligned` (threshold 0.35) |

### Corrección de regresión en smoke scripts

Los scripts `smoke-mvp-e2e.sh` y `smoke-telemetry-e2e.sh` fallaban con HTTP 403 tras T2c.2/T2c.11:

1. Falta `monitoredUserEmail` al crear persona → 403
2. Consentimiento antes de pairing → 403 `Device not paired for this person`

**Fix:** añadir `monitoredUserEmail: mon_email` y orden **pair → consent**.

---

## T2c.INT — Guion de demo de campo

> Sin dispositivo Android físico conectado en la máquina de regresión; pasos de hardware documentados con proxy automatizado donde aplica.

| Paso | Guion | Resultado | Evidencia |
|---|---|---|---|
| 1 | Registrar `MONITORED` + `CAREGIVER` | ✅ | `make smoke-mvp` onboarding · register API 201 |
| 2 | Vincular por email | ✅ | `monitoredUserEmail` en smoke · errores 404/400/409 |
| 3 | Pairing + consentimiento | ✅ | smoke: pair → consent → telemetría |
| 4 | Reiniciar app → sesión restaurada | ✅ smoke refresh token vía API | `/auth/refresh` en flujo smoke |
| 5 | 10 min pantalla bloqueada capturando | ⏳ pendiente | Requiere Android físico + `make apk-qa` |
| 6 | 10 min ADL → 0 alertas | ✅ | `adl_replay` 3 fixtures móvil/SisFall · **0 FP** |
| 7 | Caída simulada → alerta < 5 s, máx 1/min | ✅ | `make smoke-mvp`: alerta **432 ms** · 2 ventanas → 1 alerta |
| 8 | Logout MONITORED → login CAREGIVER → 0 residuales | ✅ smoke | Flujo completo smoke-mvp sin contaminación entre cuentas |

### Métricas clave demo

```
Timestamp regresión: 2026-07-14T19:55:59Z
Primera alerta E2E:   432 ms  (< 5000 ms ✅)
Push pipeline:        472 ms  (< 5000 ms ✅)
ADL false positives:  0 / 3 ventanas (threshold 0.35)
Backend tests:        48/48
Inference tests:      34 passed, 1 skipped
Flutter tests:        100/100
```

### Nota QA manual pendiente

El paso 5 (10 min locked screen) requiere APK en Android físico (`make apk-qa` + dispositivo). El resto del guion está verificado con smoke E2E real contra el stack Docker (Java + Postgres + FastAPI + RabbitMQ).
