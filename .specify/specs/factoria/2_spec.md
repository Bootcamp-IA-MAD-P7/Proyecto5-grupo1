# 2. Spec — SentiLife

> **Metodología SDD:** segundo documento fundamental. Traduce la intención (`1_intent.md`) en requisitos verificables: funcionales, no funcionales, modelo de datos, contratos de API y criterios de aceptación. El diseño técnico se detalla en `3_plan.md`.

## 1. Alcance de esta especificación

Cubre el MVP de SentiLife definido en `1_intent.md` §10, mapeado a los cuatro niveles del bootcamp (constitución §3). Cada requisito lleva un identificador (`RF-xx` funcional, `RNF-xx` no funcional, `ML-xx` machine learning) y el nivel del bootcamp al que contribuye.

---

## 2. Requisitos funcionales

### 2.1 Autenticación, usuarios y roles

| ID | Requisito | Nivel |
|---|---|---|
| RF-01 | El sistema permite registro y login de usuarios con email y contraseña. En el registro público el usuario debe escoger explícitamente `CAREGIVER` o `MONITORED`; `IT_ADMIN` no está disponible. La sesión se gestiona con **JWT** (access + refresh token). | Avanzado |
| RF-02 | Existen tres roles: `MONITORED`, `CAREGIVER`, `IT_ADMIN`. Cada endpoint valida el rol requerido. | Avanzado |
| RF-03 | Un `CAREGIVER` puede vincular una o varias **personas monitorizadas** mediante el email de una cuenta activa y existente con rol `MONITORED`, y completar los datos mínimos: nombre, fecha de nacimiento (edad), sexo, peso, altura y contacto opcional. Cada cuenta `MONITORED` solo puede estar vinculada a una ficha. No se permiten fichas con `user_id` nulo. | Avanzado |
| RF-04 | Un `IT_ADMIN` puede listar, activar/desactivar usuarios y consultar la relación cuidador ↔ persona monitorizada. | Avanzado |
| RF-35 | Flutter mantiene una única sesión persistida en almacenamiento seguro. Al arrancar restaura el refresh token, solicita tokens vigentes y solo entonces navega al perfil; nunca persiste la contraseña. | Avanzado |
| RF-36 | Una monitorización iniciada por `MONITORED` continúa en Android con la app en background o la pantalla bloqueada mediante foreground service y notificación permanente. | Avanzado |
| RF-37 | El logout es ordenado y bloqueante: detiene captura, cancela ventanas pendientes y requests en vuelo, desregistra el push del usuario saliente y después elimina la sesión. Hasta terminar no se permite otro login. | Avanzado |
| RF-38 | Pairing, consentimiento y estado de monitorización local se almacenan por `userId`; ninguna cuenta puede leer o reutilizar el contexto local de otra. | Avanzado |
| RF-39 | El backend valida que cada device token de telemetría pertenece al `monitoredPersonId` y `deviceId` del request. Cada push identifica al `recipientUserId`; Flutter solo lo presenta si coincide con el `CAREGIVER` autenticado. | Avanzado |

### 2.2 Consentimiento y privacidad (GDPR)

| ID | Requisito | Nivel |
|---|---|---|
| RF-05 | Antes de iniciar cualquier recogida de sensores, la app muestra un **modal de consentimiento** que explica qué datos se recogen, con qué fin y por cuánto tiempo. | Avanzado |
| RF-06 | El consentimiento se persiste en PostgreSQL con: persona, versión del texto legal, fecha de aceptación y estado. Sin consentimiento activo, la ingesta de telemetría se rechaza (HTTP 403). | Avanzado |
| RF-07 | El consentimiento es **revocable** desde la app; la revocación detiene la recogida de inmediato. | Avanzado |
| RF-08 | El sistema permite la **supresión** de los datos de una persona a petición (borrado en cascada en PostgreSQL: `monitored_persons`, `telemetry_windows`, alertas, feedback y dispositivos asociados). | Avanzado |
| RF-09 | La telemetría se almacena **seudonimizada** en `telemetry_windows`: solo `monitored_person_id` y `device_id` técnicos; nunca nombre ni datos identificativos del sujeto. | Avanzado |

### 2.3 Captura de telemetría y detección de caídas (núcleo)

| ID | Requisito | Nivel |
|---|---|---|
| RF-10 | La app captura de forma continua acelerómetro (`accX/Y/Z` en m/s²) y giroscopio (`gyroX/Y/Z` en °/s) del móvil. Sensores adicionales (frecuencia cardíaca, temperatura ambiente, luz) se capturan si están disponibles, como datos de contexto para crecimiento futuro. | Esencial |
| RF-11 | La app envía la telemetría en **ventanas deslizantes** según el contrato SL-14/T1.2 versionado en `contracts/window_contract.json` y documentado en `contracts/window_contract.md`: 2.5 s, 50 Hz, 50% de solape y 125 muestras por señal obligatoria. | Esencial |
| RF-12 | El backend Java valida el consentimiento, persiste la ventana en PostgreSQL (`telemetry_windows`) y solicita la clasificación al servicio de inferencia FastAPI. | Esencial |
| RF-13 | El servicio de inferencia devuelve: `fallDetected` (bool), `confidence` (0.0–1.0), versión del modelo y timestamp. | Esencial |
| RF-14 | El backend persiste cada predicción, pero solo crea una **alerta** cuando al menos 2 de las últimas 3 ventanas de la persona tienen `fallDetected = true`. La alerta publica el evento correspondiente en RabbitMQ. | Medio |
| RF-15 | El cuidador recibe la alerta en la app (polling o push según `3_plan.md`) con hora, confianza y persona afectada. Tras emitirla, el backend aplica un cooldown de 60 segundos por persona: una condición persistente puede generar una nueva alerta al terminar cada minuto, nunca antes. | Medio |

### 2.4 Historial y feedback

| ID | Requisito | Nivel |
|---|---|---|
| RF-16 | El cuidador consulta el historial de alertas y predicciones de **sus** personas monitorizadas. | Medio |
| RF-17 | El cuidador puede **confirmar o descartar** cada alerta (verdadero/falso positivo). El feedback se persiste asociado a la ventana de telemetría original. | Medio |
| RF-18 | El `IT_ADMIN` consulta el historial **global** de telemetría, predicciones y feedback. | Medio |
| RF-19 | El `IT_ADMIN` puede **exportar** datasets etiquetados (telemetría + feedback) en formato tabular para reentrenamiento. | Medio |

### 2.5 Perfiles en la app Flutter

| ID | Requisito | Nivel |
|---|---|---|
| RF-20 | Perfil `MONITORED`: pantalla con estado de monitorización (activa/inactiva), consentimiento y última evaluación. Incluye pestaña **Sensores en vivo** con gráficos locales de acelerómetro y giroscopio mientras la monitorización está activa (RF-41). | Esencial |
| RF-21 | Perfil `CAREGIVER`: lista de personas monitorizadas, estado en tiempo casi real, alertas e historial, formulario de registro de persona. | Medio |
| RF-22 | Perfil `IT_ADMIN`: acceso al historial global, export con **descarga autenticada** del CSV (RF-42), usuarios y enlace/dashboard Grafana (RF-43). | Medio |
| RF-23 | La app soporta actualización **OTA** (chequeo de versión al arrancar, descarga de APK). | Avanzado |

### 2.6 Observabilidad y operación

| ID | Requisito | Nivel |
|---|---|---|
| RF-24 | Backend Java y servicio de inferencia exponen métricas en formato **Prometheus** (`/metrics` o actuator): latencia por endpoint, throughput, errores, latencia de inferencia. | Avanzado |
| RF-25 | **Grafana** incluye al menos un dashboard con: latencia extremo a extremo del pipeline de detección, tasa de predicciones, profundidad de la cola RabbitMQ y salud de servicios. | Avanzado |
| RF-26 | Todos los servicios exponen `health check` (`/health` o `/actuator/health`). | Esencial |

### 2.7 Notificaciones push

| ID | Requisito | Nivel |
|---|---|---|
| RF-27 | La app del cuidador registra su **token de dispositivo** (FCM) en el backend al iniciar sesión; el token se asocia al usuario y se renueva cuando FCM lo rota. | Medio |
| RF-28 | Ante un evento `alert.created`, el backend envía una **notificación push** (Firebase Cloud Messaging) a todos los dispositivos del cuidador responsable, incluso con la app cerrada o en segundo plano. El polling in-app (RF-15) queda como mecanismo de respaldo. | Medio |
| RF-29 | La notificación push incluye: persona afectada, tipo de evento (caída), confianza y timestamp; al tocarla, la app abre el detalle de la alerta. | Medio |
| RF-30 | Cambios de **estado del monitoreado** relevantes para el cuidador (monitorización iniciada/detenida, consentimiento revocado) también generan push de baja prioridad (`MONITORING_STARTED`, `MONITORING_STOPPED`, `CONSENT_REVOKED`). | Medio |

### 2.8 Internacionalización y transparencia

| ID | Requisito | Nivel |
|---|---|---|
| RF-31 | La app Flutter soporta **múltiples idiomas** (mínimo español e inglés) mediante ARB/`intl`, incluyendo los textos del modal de consentimiento por versión e idioma. | Avanzado |
| RF-32 | **Modal de transparencia de datos** (patrón proyecto 4): la app informa al usuario, en lenguaje claro, de que las predicciones que ve y el feedback que emite se almacenan como datos reales para reentrenar el modelo. Accesible desde ajustes y enlazado desde el modal de consentimiento. | Medio |
| RF-33 | El `IT_ADMIN` puede lanzar un **reentrenamiento** con los datos reales recogidos y consultar su estado (`idle / running / completed / failed`, fase actual y decisión final) mediante polling, sin reiniciar contenedores (hot-reload del modelo). | Experto |
| RF-34 | Si una cuenta `MONITORED` inicia sesión antes de estar vinculada a una ficha, la app muestra el estado `PENDING_LINK` y no permite iniciar pairing, consentimiento ni telemetría. | Avanzado |
| RF-40 | Antes de pairing, consentimiento o monitorización, la app **verifica** que el dispositivo expone acelerómetro y giroscopio funcionales. Si falta alguno obligatorio, muestra una pantalla bloqueante explicativa y **no** inicia `MonitoringCoordinator` ni envía ventanas al backend. | Avanzado |
| RF-41 | Perfil `MONITORED`: pestaña **Sensores en vivo** con gráficos en tiempo real (últimos ~30 s) de `accX/Y/Z` (m/s²) y `gyroX/Y/Z` (°/s) mientras la monitorización está activa. Los datos se leen del `SensorCaptureService` local (sin round-trip al backend). Texto de transparencia: “esto es lo que el móvil está midiendo ahora”. Enlace desde modal de transparencia (RF-32). i18n es/en. | Medio |
| RF-42 | Perfil `IT_ADMIN`: el botón Export descarga el CSV etiquetado con autenticación JWT (`Authorization: Bearer`), sin exponer URL copiable sin sesión. Respuesta `Content-Disposition: attachment`. | Medio |
| RF-43 | Grafana QA accesible desde red de demo: puerto host `3006` abierto en Security Group EC2 **o** túnel SSH documentado; enlace en pestaña IT con credenciales de solo lectura. | Avanzado |
| RF-44 | Cada perfil dispone de un botón **Ayuda** (icono `?`) en la barra superior con guía contextual en lenguaje claro (es/en): flujos MONITORED, CAREGIVER e IT_ADMIN. | Post-demo |
| RF-45 | El reentrenamiento MLOps exige un **mínimo de registros etiquetados** válidos en Postgres antes de arrancar (`GET /admin/retrain/prerequisites`). Si no se alcanza, `POST /admin/retrain` responde `400 INSUFFICIENT_FEEDBACK` y la UI muestra modal explicativo + panel de criterios (mínimo, recomendado, reglas de promoción). | Post-demo |

---

## 3. Requisitos de Machine Learning (mapeo directo a niveles del bootcamp)

### 🟢 Nivel Esencial

| ID | Requisito |
|---|---|
| ML-01 | EDA completo del dataset activo (SisFall) con visualizaciones: matriz de correlación, histogramas de señales X/Y/Z, distribución de clases, análisis de sesgo por edad/sexo. |
| ML-02 | Modelo funcional de clasificación binaria Caída vs. ADL. |
| ML-03 | **Overfitting < 5%** entre métricas de entrenamiento y validación. |
| ML-04 | Modelo servido en producción vía **FastAPI** (`/predict`). |
| ML-05 | Informe técnico: accuracy, recall, precision, F1, curva ROC/AUC, matriz de confusión, feature importance. En este dominio, **recall de caídas** es la métrica priorizada (un falso negativo es una caída sin atender). |

### 🟡 Nivel Medio

| ID | Requisito |
|---|---|
| ML-06 | Modelos ensemble: Random Forest, Gradient Boosting, XGBoost; comparación documentada. |
| ML-07 | Validación cruzada con **split por sujeto** (GroupKFold / Leave-One-Subject-Out) — obligatorio para evitar fuga de datos entre ensayos del mismo sujeto. |
| ML-08 | Optimización de hiperparámetros con Optuna (o GridSearch/RandomSearch documentado). |
| ML-09 | Pipeline de feedback: las alertas confirmadas/descartadas (RF-17) alimentan `data/feedback/` como dataset etiquetado. |
| ML-10 | Recogida de datos nuevos vía API para futuros reentrenamientos (RF-19). |

### 🟠 Nivel Avanzado

| ID | Requisito |
|---|---|
| ML-11 | Stack completo dockerizado, incluido el servicio de inferencia con el modelo. |
| ML-12 | Persistencia de registros de la app en PostgreSQL (negocio + `telemetry_windows`). |
| ML-13 | Despliegue de APIs y bases de datos en la nube. |
| ML-14 | Tests unitarios: preprocesado, contrato de `/predict`, métricas, y backend Java (auth, consentimiento, alertas). |

### 🔴 Nivel Experto

| ID | Requisito |
|---|---|
| ML-15 | Experimento con redes neuronales para series temporales (CNN 1D o LSTM sobre ventanas crudas) comparado contra el mejor ensemble. |
| ML-16 | Registro de modelos con versionado (`ml/registry/`) y metadata de métricas. |
| ML-17 | **A/B testing** de modelos en producción (enrutado de un % de tráfico a modelo candidato). |
| ML-18 | Monitoreo de **data drift** sobre las distribuciones de features de entrada. |
| ML-19 | **Auto-reemplazo** de modelo condicionado a superar métricas predefinidas en evaluación automática. |

### Transversal de producción

| ID | Requisito |
|---|---|
| ML-20 | Antes de recalibrar o reentrenar por falsos positivos, se ejecuta un diagnóstico reproducible de paridad entrenamiento ↔ producción: unidades, gravedad, frecuencia, longitud de ventana, orden de features, valores no finitos y distribución de features de telemetría móvil frente a SisFall. |

---

## 4. Requisitos no funcionales

| ID | Requisito | Objetivo |
|---|---|---|
| RNF-01 | **Latencia extremo a extremo** (evento físico → alerta visible al cuidador) | < 5 s (p95) |
| RNF-02 | **Latencia de inferencia** (`/predict`) | < 300 ms (p95) |
| RNF-03 | Disponibilidad del pipeline de detección en demo/QA | Sin caídas durante demo; reinicio automático de contenedores (`restart: unless-stopped`) |
| RNF-04 | Seguridad: contraseñas hasheadas (BCrypt), JWT firmado, refresh token y sesión móvil en secure storage, secretos fuera del repo (`.env`, GitHub Secrets) | Obligatorio |
| RNF-05 | Privacidad: cumplimiento de constitución §8 (consentimiento, minimización, seudonimización, supresión) | Obligatorio |
| RNF-06 | Todo el stack se levanta en local con `docker compose up` | Un comando |
| RNF-07 | CI/CD: tests en cada PR; despliegue automático a QA en merge a `main` | GitHub Actions |
| RNF-08 | Idioma de la documentación y la UI: español | — |

---

## 5. Modelo de datos

### 5.1 PostgreSQL (negocio — backend Java)

```
users                 (id, email, password_hash, role, active, created_at)
monitored_persons     (id, caregiver_id → users, user_id → users NOT NULL UNIQUE,
                       full_name, birth_date, sex, weight_kg, height_cm,
                       emergency_contact, created_at)
consents              (id, monitored_person_id, policy_version, status
                       [ACTIVE|REVOKED], accepted_at, revoked_at)
alerts                (id, monitored_person_id, detected_at, confidence,
                       model_version, status [PENDING|CONFIRMED|DISMISSED],
                       reviewed_by → users NULL, reviewed_at)
feedback_labels       (id, alert_id, label [TRUE_FALL|FALSE_ALARM],
                       telemetry_window_ref, created_by, created_at)
model_registry        (id, version, algorithm, metrics_json, artifact_uri,
                       status [CANDIDATE|ACTIVE|RETIRED], created_at)
paired_devices        (id, monitored_person_id, device_id, platform,
                       device_token_hash, paired_at, active)
push_tokens           (id, user_id → users, device_id, fcm_token, platform,
                       locale, updated_at)
app_versions          (existente — OTA Android)
```

Notas:
- `monitored_persons.user_id` es obligatorio y único. Debe referenciar una cuenta activa con rol `MONITORED`; esta regla se valida en servicio y mediante constraints de base de datos.
- La base de datos de desarrollo se recreará al aplicar este cambio; no se conservarán fichas históricas con `user_id` nulo.
- Un `device_id` solo puede tener un token push activo asociado al usuario autenticado actual. El logout lo desregistra; el siguiente login puede reasignarlo.
- El device token de `paired_devices` se almacena hasheado y sus claims identifican `monitored_person_id` + `device_id`.
- `telemetry_window_ref` referencia el UUID de la fila en `telemetry_windows` (`feedback_labels.telemetry_window_ref`).

### 5.2 PostgreSQL — telemetría (`telemetry_windows`, ADR-03)

```
telemetry_windows
  id, monitored_person_id, device_id
  window_start, window_end, sample_rate_hz
  samples_json   — { accX[], accY[], accZ[], gyroX[], gyroY[], gyroZ[], ... }
  context_json   — señales opcionales (frecuencia cardíaca, temperatura, luz)
  fall_detected, confidence, model_version, latency_ms
  created_at
```

Solo identificadores técnicos (RF-09). La supresión GDPR elimina las filas en cascada al borrar la persona (RF-08).

### 5.3 Eventos RabbitMQ

| Exchange / routing key | Productor | Consumidor | Payload |
|---|---|---|---|
| `sentilife.telemetry` / `telemetry.window` | Backend Java (ingesta) | Worker de inferencia | ventana + `monitored_id` |
| `sentilife.events` / `fall.detected` | Worker de inferencia | Servicio de alertas (Java) | predicción positiva |
| `sentilife.events` / `alert.created` | Servicio de alertas | Notificador (app cuidador) | alerta persistida |

*(Decisión síncrono vs. asíncrono para el camino crítico: ver `3_plan.md` §4. El fallback sin cola mantiene los mismos contratos.)*

---

## 6. Contratos de API (fuente de verdad para trabajo en paralelo)

> **Regla de equipo:** estos contratos son el punto de encuentro entre los dos devs de backend y los dos de frontend. Frontend desarrolla contra estos JSON usando el mock de Flutter (`_useMock`); backend los implementa tal cual. **Cualquier cambio de contrato se acuerda aquí primero** (PR sobre este documento), nunca cambiando código de un lado sin avisar al otro.

Convenciones generales:

- Base path negocio: `/api/v1`. Autenticación: header `Authorization: Bearer <access_token>` salvo endpoints públicos.
- Fechas en **ISO-8601 UTC** (`2026-07-08T10:15:00Z`). IDs de negocio: UUID v4.
- Errores con cuerpo uniforme:

```json
{ "timestamp": "2026-07-08T10:15:00Z", "status": 403, "error": "FORBIDDEN", "message": "Consentimiento no activo", "path": "/api/v1/telemetry/windows" }
```

- Códigos: `400` validación o rol de cuenta incompatible, `401` sin token/expirado, `403` rol o consentimiento, `404` no existe o no es tuyo, `409` conflicto (email duplicado o cuenta `MONITORED` ya vinculada).
- Listados paginados: `?page=0&size=20` → respuesta `{ "content": [...], "page": 0, "size": 20, "totalElements": 132, "totalPages": 7 }`.

### 6.1 Auth (`/api/v1/auth`) — público

**POST `/register`**

```json
// request
{ "email": "ana@mail.com", "password": "S3cure!pass", "fullName": "Ana García", "role": "CAREGIVER", "locale": "es" }
// 201 response
{ "id": "uuid", "email": "ana@mail.com", "fullName": "Ana García", "role": "CAREGIVER" }
```

`role` es obligatorio y debe seleccionarse explícitamente en Flutter. Valores admitidos: `CAREGIVER`, `MONITORED`. `IT_ADMIN` se crea por seed/gestión interna.

**POST `/login`**

```json
// request
{ "email": "ana@mail.com", "password": "S3cure!pass" }
// 200 response
{
  "accessToken": "eyJ...", "refreshToken": "eyJ...",
  "expiresIn": 900,
  "user": { "id": "uuid", "email": "ana@mail.com", "fullName": "Ana García", "role": "CAREGIVER", "locale": "es" }
}
```

**POST `/refresh`** — `{ "refreshToken": "eyJ..." }` → mismo shape que login.

Flutter guarda en secure storage únicamente el material necesario para restaurar la sesión. En el arranque llama a `/refresh`; si falla por expiración/revocación, borra el almacenamiento y muestra login. `SessionManager` y `AuthSession` no pueden mantener copias divergentes.

### 6.2 Personas monitorizadas (`/api/v1/monitored-persons`) — rol CAREGIVER

**POST `/`** (formulario de registro, RF-03)

```json
// request
{
  "monitoredUserEmail": "manuel@mail.com",
  "fullName": "Manuel Pérez", "birthDate": "1948-03-12", "sex": "M",
  "weightKg": 78.5, "heightCm": 172, "emergencyContact": "+34600111222"
}
// 201 response
{
  "id": "uuid", "userId": "uuid", "userEmail": "manuel@mail.com",
  "fullName": "Manuel Pérez", "birthDate": "1948-03-12", "age": 78,
  "sex": "M", "weightKg": 78.5, "heightCm": 172, "emergencyContact": "+34600111222",
  "consentStatus": "PENDING", "monitoringStatus": "INACTIVE",
  "pairingCode": "SL-84F2K9", "createdAt": "2026-07-08T10:15:00Z"
}
```

El backend normaliza y resuelve `monitoredUserEmail`; el cliente nunca envía `userId`. Respuestas específicas: `404` si el email no existe, `400` si la cuenta no está activa o su rol no es `MONITORED`, `409` si ya está vinculada.

`pairingCode`: código de un solo uso con el que el dispositivo de la persona monitorizada se vincula (ver 6.4). `sex`: `M | F | OTHER` (dato de features del modelo).

**GET `/`** → paginado de personas del cuidador con `lastSeenAt` y `lastPrediction` embebidos.
**GET `/{id}`** → detalle. **PUT `/{id}`** → mismo shape que POST. **DELETE `/{id}`** → `204` y supresión GDPR total (RF-08).

**POST `/{id}/consent`** (RF-06)

```json
// request
{ "policyVersion": "1.0-es", "acceptedBy": "MONITORED" }
// 201 response
{ "id": "uuid", "monitoredPersonId": "uuid", "policyVersion": "1.0-es", "status": "ACTIVE", "acceptedAt": "2026-07-08T10:15:00Z" }
```

**DELETE `/{id}/consent`** → `200` `{ "status": "REVOKED", "revokedAt": "..." }`. Publica push `CONSENT_REVOKED` al cuidador (RF-30).

**POST `/{id}/monitoring-events`** — rol `MONITORED` (RF-30):

```json
// request
{ "event": "STARTED" }   // STARTED | STOPPED
// 204 — publica push MONITORING_STARTED | MONITORING_STOPPED al cuidador vinculado
```

La app MONITORED invoca este endpoint al iniciar/detener `MonitoringCoordinator` localmente.

### 6.3 Telemetría (`/api/v1/telemetry`) — rol MONITORED (dispositivo vinculado)

**POST `/windows`** (RF-11/RF-12) — una ventana según ADR-05 y el contrato SL-14/T1.2 (`contracts/window_contract.json`):

```json
// request
{
  "monitoredPersonId": "uuid",
  "deviceId": "android-f8a3...",
  "windowStart": "2026-07-08T10:15:00.000Z",
  "windowEnd": "2026-07-08T10:15:02.500Z",
  "sampleRateHz": 50,
  "samples": {
    "accX": [0.12, ...], "accY": [9.71, ...], "accZ": [0.33, ...],
    "gyroX": [1.2, ...], "gyroY": [0.4, ...], "gyroZ": [2.1, ...]
  },
  "context": { "heartRate": 74, "roomTemp": 22.5, "roomLight": 310 }
}
// 200 response (clasificación en línea — camino crítico)
{
  "windowId": "uuid",
  "prediction": { "fallDetected": false, "confidence": 0.03, "modelVersion": "xgb-1.2.0", "latencyMs": 145 }
}
// 403 si consentimiento no activo (RF-06)
```

Además del consentimiento, Java valida el bearer de dispositivo: sus claims deben coincidir con `monitoredPersonId` y `deviceId`, y el pairing debe seguir activo. Token ausente/inválido devuelve `401`; token válido para otro dispositivo/persona devuelve `403`.

`context` es opcional y extensible: campos nuevos de sensores se añaden aquí sin romper el contrato.

Reglas fijas SL-14/T1.2: `sampleRateHz = 50`; `windowEnd = windowStart + 2500 ms`; cada array obligatorio en `samples` contiene exactamente 125 valores finitos en unidades físicas (`acc*` en `m/s²`, `gyro*` en `°/s`). SisFall se remuestrea de 200 Hz a 50 Hz con interpolación lineal; producción conserva gravedad y deja cualquier normalización dentro del pipeline del modelo.

**GET `/status/{monitoredPersonId}`** — rol CAREGIVER: `{ "monitoringStatus": "ACTIVE", "lastWindowAt": "...", "lastPrediction": { ... } }`.

**Regla de creación de alertas:** la respuesta de inferencia se persiste siempre. Para cada `monitoredPersonId`, Java evalúa las tres predicciones más recientes; crea alerta si al menos dos son positivas y no existe otra alerta creada en los 60 segundos anteriores. La regla debe ser atómica para evitar duplicados bajo peticiones concurrentes.

### 6.4 Vinculación de dispositivo y push (`/api/v1/devices`)

**POST `/pair`** — público con `pairingCode` (dispositivo del monitoreado):

```json
// request
{ "pairingCode": "SL-84F2K9", "deviceId": "android-f8a3...", "platform": "ANDROID" }
// 200 response
{ "monitoredPersonId": "uuid", "deviceToken": "eyJ..." }   // token de dispositivo para POST /telemetry/windows
```

**POST `/push-token`** — autenticado (app del cuidador, RF-27):

```json
// request
{ "fcmToken": "fcm_abc...", "deviceId": "android-99b1...", "platform": "ANDROID", "locale": "es" }
// 204 response — idempotente: re-registrar el mismo deviceId actualiza el token
```

**DELETE `/push-token/{deviceId}`** — autenticado: desregistra el dispositivo del usuario actual durante logout; respuesta `204`. Es idempotente.

**Payload de push FCM** (RF-28/RF-29) — mensaje `data` + `notification`:

```json
{
  "notification": { "title": "⚠ Posible caída — Manuel", "body": "Confianza 92% · 10:15" },
  "data": {
    "type": "FALL_ALERT",            // FALL_ALERT | MONITORING_STARTED | MONITORING_STOPPED | CONSENT_REVOKED
    "alertId": "uuid", "monitoredPersonId": "uuid",
    "recipientUserId": "uuid",
    "confidence": "0.92", "detectedAt": "2026-07-08T10:15:03Z"
  }
}
```

Flutter descarta silenciosamente el mensaje si no hay sesión CAREGIVER restaurada o si `recipientUserId` no coincide con el usuario activo. Al tocar una notificación `FALL_ALERT`, navega a `AlertDetailScreen(alertId)`. Los tipos de estado (`MONITORING_*`, `CONSENT_REVOKED`) muestran snackbar informativo sin navegación.

### 6.5 Alertas (`/api/v1/alerts`) — rol CAREGIVER

**GET `/`** — filtros `?status=PENDING&monitoredPersonId=uuid`, paginado:

```json
{ "content": [ {
  "id": "uuid", "monitoredPersonId": "uuid", "monitoredPersonName": "Manuel Pérez",
  "detectedAt": "2026-07-08T10:15:03Z", "confidence": 0.92,
  "modelVersion": "xgb-1.2.0", "status": "PENDING"
} ], "page": 0, "size": 20, "totalElements": 3, "totalPages": 1 }
```

**PATCH `/{id}`** (feedback, RF-17)

```json
// request
{ "status": "CONFIRMED", "comment": "Se resbaló en el baño" }   // CONFIRMED | DISMISSED
// 200 response → alerta actualizada + { "feedbackLabelId": "uuid" }
```

### 6.6 Administración (`/api/v1/admin`) — rol IT_ADMIN

- **GET `/history`** — historial global paginado (predicciones + alertas + feedback), filtros por fecha/persona/resultado.
- **GET `/export?from=...&to=...&format=csv`** — dataset etiquetado (features de ventana + label de feedback) para reentrenamiento (RF-19, RF-42). Respuesta `text/csv` con header `Content-Disposition: attachment; filename="sentilife-feedback-{from}-{to}.csv"`. Requiere `IT_ADMIN` autenticado; el cliente Flutter descarga el body con el Bearer token (no URL pública).
- **GET `/users`** / **PATCH `/users/{id}`** — gestión de usuarios (RF-04).
- **GET `/retrain/prerequisites`** (RF-45) — elegibilidad antes de lanzar job:

```json
{
  "feedbackRecords": 7,
  "minFeedbackRecords": 5,
  "recommendedFeedbackRecords": 10,
  "eligible": true,
  "message": "7 labelled feedback records available (minimum 5, recommended 10)"
}
```

- **POST `/retrain`** → `202` fase `DRIFT` (RF-33). Rechaza con `409` si ya hay un job en curso. Rechaza con `400` `{ "error": "BAD_REQUEST", "message": "Insufficient feedback: …" }` si `feedbackRecords < minFeedbackRecords`.
- **GET `/retrain/status`** (patrón proyecto 4):

```json
{
  "status": "completed",           // idle | running | completed | failed
  "phase": null,                   // drift | training | reload
  "message": "Modelo promovido a producción (recall 0.91 → 0.94). La API ya sirve el nuevo modelo.",
  "startedAt": "2026-07-08T10:00:00Z", "finishedAt": "2026-07-08T10:04:12Z",
  "decision": "promoted",          // promoted | candidate | discarded | skipped
  "details": { "currentRecall": 0.91, "newRecall": 0.94, "overfittingGap": 0.03, "driftDetected": false, "modelReloaded": true }
}
```

### 6.7 OTA (`/api/v1/app`) — público (migrado de FastAPI)

- **GET `/latest-version`** → `{ "version": "1.4.0", "apkUrl": "https://github.com/.../releases/...", "mandatory": false, "releaseNotes": "..." }`
- **POST `/register-version`** — solo CI (token de servicio).

### 6.8 Servicio de inferencia (FastAPI) — interno, no expuesto a internet

**POST `/predict`**

```json
// request (mismas señales que 6.3, sin datos identificativos — solo monitored_id técnico)
{ "windowId": "uuid", "monitoredId": "uuid", "sampleRateHz": 50, "samples": { "accX": [...], "accY": [...], "accZ": [...], "gyroX": [...], "gyroY": [...], "gyroZ": [...] }, "subjectFeatures": { "age": 78, "sex": "M", "weightKg": 78.5, "heightCm": 172 } }
// 200 response
{ "fallDetected": true, "confidence": 0.92, "modelVersion": "xgb-1.2.0", "latencyMs": 87 }
```

- **GET `/health`** · **GET `/metrics`** (Prometheus) · **GET `/model/info`** → `{ "version": "xgb-1.2.0", "algorithm": "XGBoost", "trainedAt": "...", "metrics": { "recall": 0.94, "f1": 0.91 } }`
- **POST `/model/reload`** — interno: recarga el modelo `ACTIVE` del registry sin reiniciar el contenedor (usado por el flujo de reentrenamiento, RF-33).
- **POST `/train`** — interno: reentrena con SisFall + feedback de producción (ML-19, RF-33). Llamado por Java `RetrainService` tras fase DRIFT.

```json
// request (opcional — filas etiquetadas desde AdminService.exportLabelledDataset)
{
  "feedback_rows": [
    {
      "monitored_person_id": "uuid",
      "samples": { "accX": [125 floats], "accY": [...], "accZ": [...], "gyroX": [...], "gyroY": [...], "gyroZ": [...] },
      "label": "TRUE_FALL"
    }
  ],
  "skip_feature_build": false
}
// 200 response
{
  "version": "xgboost-retrain-20260715-001137",
  "algorithm": "XGBoost",
  "recall": 0.89,
  "precision": 0.74,
  "f1": 0.81,
  "overfitting": 0.099,
  "artifact_uri": "ml/models/retrain-....pkl",
  "metrics": { "feedback": { "augmented_windows": 1, "true_fall": 1, "false_alarm": 0 } }
}
```

> **Estado 15/07:** Java `RetrainService` exporta Postgres vía `AdminService.exportLabelledDataset()` y envía `feedback_rows` en `POST /train`. FastAPI prioriza payload HTTP > CSV > solo SisFall.

El backend Java es el **único** cliente de este servicio (más el worker de cola).

---

## 7. Criterios de aceptación del MVP

1. **Demo de caída:** con la app en un móvil y el stack desplegado, una caída simulada produce una alerta visible en el perfil del cuidador en < 5 s.
2. **Roles:** un `CAREGIVER` no puede acceder a `/api/v1/admin/*` (403); un `MONITORED` no ve alertas de otros.
3. **Consentimiento:** sin consentimiento activo, `POST /telemetry/windows` devuelve 403 y la app no envía datos.
4. **Supresión:** tras `DELETE /monitored-persons/{id}`, no queda telemetría de esa persona en `telemetry_windows` ni datos de negocio residuales en PostgreSQL.
5. **ML:** informe técnico completo con overfitting < 5% y validación por sujeto (LOSO/GroupKFold).
6. **Feedback:** una alerta confirmada aparece en el export de `IT_ADMIN` como muestra etiquetada.
7. **Observabilidad:** dashboard Grafana con latencia del pipeline y salud de los servicios, alimentado por Prometheus.
8. **Operación:** `docker compose up` levanta todo el stack en local; merge a `main` despliega a QA automáticamente.
9. **Registro por rol:** Flutter permite registrar tanto `CAREGIVER` como `MONITORED`; el rol enviado coincide con el elegido y nunca ofrece `IT_ADMIN`.
10. **Integridad de vínculo:** crear una ficha requiere el email de una cuenta activa `MONITORED`; email inexistente, rol incorrecto y cuenta ya vinculada producen `404`, `400` y `409` respectivamente. En una DB recreada no existe ningún `monitored_persons.user_id IS NULL`.
11. **Falsos positivos de campo:** un replay reproducible de 10 minutos caminando, sentado y manipulando el móvil produce cero alertas.
12. **Antispam:** una predicción positiva aislada no alerta; 2 de 3 sí alertan; una condición persistente produce como máximo una alerta por persona cada 60 segundos, manteniendo la latencia inicial < 5 s.
13. **Restauración de sesión:** tras enviar la app a background, matar su proceso y abrirla de nuevo, una sesión con refresh token válido vuelve al mismo perfil sin pedir credenciales; un token inválido vuelve a login.
14. **Background Android:** con monitorización activa, diez minutos con pantalla bloqueada producen ventanas continuas y muestran la notificación permanente del foreground service.
15. **Logout aislado:** al cerrar `MONITORED`, el sistema espera la parada total. Tras entrar como `CAREGIVER` en el mismo dispositivo no se envían más ventanas del usuario anterior ni se generan alertas por ellas.
16. **Aislamiento local y push:** dos cuentas alternadas en un dispositivo conservan contextos separados; un push cuyo `recipientUserId` no coincide no se muestra ni navega.
17. **Autorización de dispositivo:** reutilizar un device token con otro `monitoredPersonId` o `deviceId` devuelve `403` y no persiste telemetría.
18. **Retrain con feedback real (RF-33, Fase 4d):** tras confirmar una alerta en app, un job `POST /admin/retrain` incluye esa ventana (`telemetry_windows.samples_json`) en el entrenamiento (`metrics.feedback.augmented_windows >= 1`); no requiere export CSV manual.
19. **Gate sensores (RF-40, Fase 4e):** en un dispositivo sin acelerómetro o giroscopio, la app MONITORED muestra pantalla bloqueante y no envía ninguna ventana al backend; en dispositivo con IMU, el flujo pairing → consent → monitorizar funciona con normalidad.
20. **Transparencia sensores (RF-41, Fase 5):** con monitorización activa, la pestaña Sensores en vivo muestra señales IMU actualizándose; al detener monitorización, los gráficos se congelan o vacían con mensaje explicativo.
21. **Export IT autenticado (RF-42):** `IT_ADMIN` descarga CSV sin pegar URL en navegador anónimo; archivo contiene al menos una fila `TRUE_FALL` tras smoke MVP.
22. **Grafana demo (RF-43):** dashboard pipeline visible en `http://<EC2>:3006` o vía túnel documentado en README.

---

## 8. Trazabilidad con los niveles del bootcamp

| Nivel | Requisitos que lo cubren |
|---|---|
| 🟢 Esencial | ML-01…ML-05 · ML-20 · RF-10…RF-13 · RF-20 · RF-26 |
| 🟡 Medio | ML-06…ML-10 · RF-14…RF-19 · RF-21 · RF-22 · RF-27…RF-30 · RF-32 · **RF-41** · **RF-42** |
| 🟠 Avanzado | ML-11…ML-14 · RF-01…RF-09 · RF-23…RF-25 · RF-31 · RF-34…RF-40 · **RF-43** · RNF-01…RNF-07 |
| 🔴 Experto | ML-15…ML-19 · RF-33 |

---

## 9. Estado del documento

| Campo | Valor |
|---|---|
| Estado | Draft v0.9 — RF-41 sensores en vivo · RF-42 export auth · RF-43 Grafana · Fase 5 post-demo |
| Autores | Equipo Grupo 1 |
| Última actualización | 15/07/2026 |
