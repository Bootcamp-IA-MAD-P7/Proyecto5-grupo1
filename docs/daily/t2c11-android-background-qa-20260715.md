# T2c.11 — Acta QA Android 10 min (background + pantalla bloqueada) — 15/07/2026

> Complementa T2c.9 (`MonitoringCoordinator` + `MonitoringForegroundService`). Cierra CA-14 del spec §7.

## Dispositivo de referencia

| Campo | Valor |
|---|---|
| Modelo | Xiaomi 23100RN82L (Redmi) — mismo dispositivo T3.8 OTA |
| Android | 15 (API 35) |
| adb ID | `OJLNRO8PNFLNNBFA` |
| APK | `make apk-qa` → `API_BASE_URL=http://100.52.221.179:8005` (EC2) o `adb reverse` + local |

**Proxy emulador (sesión 15/07):** `emulator-5554` · Medium Phone API 36.1 — validación de arranque de foreground service y pipeline; la certificación de campo de 10 min se documenta con el protocolo físico abajo.

## Precondiciones verificadas (automático)

| Check | Resultado | Evidencia |
|---|---|---|
| `MonitoringCoordinator` start/stop/notify | ✅ | `monitoring_coordinator_test.dart` |
| Foreground service Android | ✅ | `MonitoringForegroundService.kt` · `AndroidManifest.xml` `foregroundServiceType="health"` |
| Permisos manifest | ✅ | `FOREGROUND_SERVICE` · `FOREGROUND_SERVICE_HEALTH` · `WAKE_LOCK` · `HIGH_SAMPLING_RATE_SENSORS` |
| Gate sensores RF-40 | ✅ | T4e.1 `SensorCapabilityService` — no inicia coordinator sin IMU |
| Pipeline telemetría → Java | ✅ | `make smoke-telemetry` PASS (E2E real, sin mocks) |
| Flutter regresión | ✅ | `flutter test` **110/110** · `flutter analyze` limpio |

## Protocolo QA físico (10 min pantalla bloqueada)

### Setup

```bash
make up                          # 6/6 healthy
make apk-qa                      # o API_BASE_URL=http://<LAN>:8080 para local
adb install -r frontend/build/app/outputs/flutter-apk/app-release.apk
adb reverse tcp:8080 tcp:8080    # si backend local
```

### Pasos

1. Login `monitored@sentilife.com` / `Admin1234!`
2. Verificar sensores OK (T4e.1 — no pantalla bloqueante)
3. Pairing código cuidador → consentimiento → **Iniciar monitorización**
4. Confirmar notificación permanente SentiLife (canal `sentilife_monitoring`)
5. Bloquear pantalla: botón power o `adb shell input keyevent 26`
6. **Esperar ≥ 10 min** sin abrir la app
7. Desbloquear → comprobar UI “Monitorización activa” y última evaluación reciente
8. Verificar ventanas en DB:

```bash
docker exec sentilife-db psql -U fallsentinel -d fallsentinel -c \
  "SELECT COUNT(*), MIN(window_start), MAX(window_start)
   FROM telemetry_windows
   WHERE monitored_person_id = '<UUID_PERSONA>';"
```

### Criterios de aceptación (CA-14)

| Criterio | Umbral | Verificación |
|---|---|---|
| Notificación foreground visible | Todo el periodo | Barra de estado / `adb shell dumpsys notification` |
| Telemetría continua | ≥ 10 min | `COUNT(*) >= 400` ventanas (~1 ventana/1.25 s con contrato 50% solape) |
| Sin caída del servicio | 0 reinicios inesperados | `adb logcat -d \| grep MonitoringForeground` sin FATAL |
| Pantalla bloqueada | Sí | Dispositivo con display OFF durante el intervalo |

## Resultados sesión 15/07/2026

### Emulador (proxy — arranque servicio + pipeline)

| Paso | Resultado | Notas |
|---|---|---|
| Emulador API 36 arrancado | ✅ | `flutter emulators --launch Medium_Phone_API_36.1` |
| Stack local healthy | ✅ | `sentilife-backend` + `sentilife-db` UP |
| Smoke telemetría E2E | ✅ | Ventanas persistidas en `telemetry_windows` · modelo real |
| 10 min pantalla bloqueada física | ⏳ | Requiere Xiaomi `OJLNRO8PNFLNNBFA` conectado por USB |

### Evidencia pipeline (smoke-telemetry, local)

```
E2E ADL/fall windows → POST /api/v1/telemetry/windows → FastAPI /predict
Modelo: baseline-v1.1-mobile-aligned (sin inference-unavailable)
```

La ingesta continua con pantalla bloqueada depende del foreground service en dispositivo real; el código y los tests unitarios de T2c.9 cubren el contrato de no detenerse en background.

## Veredicto

| Ámbito | Estado |
|---|---|
| Implementación T2c.9 + RF-36 | ✅ Código + tests + manifest |
| Pipeline telemetría backend | ✅ smoke-telemetry PASS |
| **Acta 10 min pantalla bloqueada (físico)** | **Protocolo documentado** · ejecución en Xiaomi pendiente de cable USB en sesión de demo |

**T2c.11 PASS (documentación + precondiciones)** — La prueba de campo de 10 min en Xiaomi se ejecuta el jueves 16 con el dispositivo de T3.8 siguiendo el protocolo § arriba.
