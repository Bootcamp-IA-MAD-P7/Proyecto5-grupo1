> **NOTA TEMPORAL — Eliminar cuando el SDD esté completo**
>
> Este archivo es **material de referencia previo** a la metodología SDD formal de `.specify/`.
> Léelo al redactar `1_intent.md`, `2_spec.md`, `3_plan.md` y `4_task.md` en esta misma carpeta.
> Una vez su contenido esté integrado en esos cuatro archivos, **elimina este documento**.

# SDD — Fall Detector Tester

Software Design Document del proyecto de detección de caídas para personas mayores.

---

## 1. Descripción general

Aplicación móvil Flutter que detecta caídas en personas mayores usando sensores del dispositivo y un modelo entrenado con dataset. Al detectar una caída, envía una alerta de emergencia.

---

## 2. Usuarios

| Rol | Descripción |
|---|---|
| Anciano | Lleva el móvil encima. Es el sujeto monitorizado. |
| Cuidador / familiar | Recibe la alerta de emergencia. *(pendiente de definir)* |

---

## 3. Sensores y datos de entrada

| Sensor | Fuente | Estado |
|---|---|---|
| Acelerómetro | Móvil | ✅ Implementado (mock) |
| Giroscopio | Móvil | ✅ Implementado (mock) |
| Frecuencia cardíaca | Móvil / Smartwatch | ✅ Implementado (mock) |
| Temperatura de la sala | Sensor externo / API | ✅ Implementado (mock) |
| Nivel de luz de la sala | Sensor del móvil / externo | ✅ Implementado (mock) |

Los datos se procesan contra un **dataset de referencia** para clasificar si ha habido una caída.

### Lógica de clasificación actual (mock)

Se calcula la magnitud vectorial del acelerómetro y el giroscopio:

- `accel_mag = sqrt(x² + y² + z²)` → caída si > 15 m/s²
- `gyro_mag = sqrt(x² + y² + z²)` → caída si > 300 °/s

Si cualquiera de las dos supera el umbral, se clasifica como caída. Esta lógica será reemplazada por el modelo entrenado con el dataset real.

---

## 4. Plataformas

| Plataforma | Estado |
|---|---|
| Android (móvil) | ✅ Principal |
| iOS (móvil) | 🔲 Pendiente |
| Smartwatch (WearOS / Apple Watch) | 🔲 Planificado para escalado |

---

## 5. Flujo principal

```
Recoger datos de sensores
        ↓
Procesar con modelo / dataset
        ↓
¿Caída detectada?
   ├── No → Seguir monitorizando
   └── Sí → Enviar alerta de emergencia
```

---

## 6. Alertas de emergencia

- Se disparan automáticamente al detectar una caída.
- Mecanismo de envío: *(pendiente de definir — SMS, notificación push, llamada, etc.)*
- Destinatario: *(pendiente de definir — contacto de emergencia, servicio médico, etc.)*

---

## 7. Arquitectura técnica

### Estructura del repositorio

```
├── Frontend/                    # App Flutter
│   ├── lib/
│   │   ├── models/
│   │   ├── screens/
│   │   ├── services/
│   │   └── widgets/
│   └── android/                 # Plataforma principal
├── Backend/
│   ├── api/                     # FastAPI
│   ├── ml/                      # Entrenamiento y modelos
│   ├── notebooks/               # EDA y experimentos
│   ├── data/raw/                # Datasets crudos (SisFall .txt, Kaggle)
│   └── data/processed/          # CSVs tabulares y salida EDA
├── docs/daily/                  # Standups
└── .specify/specs/factoria/     # intent → spec → plan → task
```

- **Frontend:** Flutter (Dart) — `Frontend/`
- **Backend:** FastAPI + Scikit-learn/XGBoost — `Backend/`
- **Detección actual:** API en Render con lógica por umbrales (`classify()`); modelo ML entrenado en `Backend/ml/` pendiente de integrar en API
- **Package ID:** `com.jzelada.proyecto_flutter`

### Archivos principales (`Frontend/lib/`)

```
Frontend/lib/
├── main.dart                          ← entrada, tema, chequeo OTA
├── models/
│   └── prediction_result.dart         ← SensorSnapshot, FallDetectionResult
├── screens/
│   ├── home_screen.dart               ← monitorización en tiempo real
│   └── result_screen.dart             ← resultado del análisis / alerta de caída
├── services/
│   ├── api_service.dart               ← predicción (mock o API Render)
│   └── update_service.dart            ← auto-actualización Android
└── widgets/
    └── update_dialog.dart             ← diálogo de nueva versión
```

### Modelos de datos

**`SensorSnapshot`** — lectura puntual de todos los sensores:
- `accelX/Y/Z` (m/s²), `gyroX/Y/Z` (°/s), `heartRate` (ppm), `roomTemp` (°C), `roomLight` (lux)

**`FallDetectionResult`** — resultado de un análisis:
- `fallDetected` (bool), `confidence` (0.0–1.0), `snapshot`, `timestamp`

### Pantallas

| Pantalla | Descripción |
|---|---|
| `HomeScreen` | Monitorización en tiempo real, grid de sensores, botones de acción |
| `ResultScreen` | Resultado del análisis, banner de emergencia si hay caída, datos del snapshot |

---

## 8. Backend (API)

- **Framework:** FastAPI (Python)
- **Deploy:** Render (plan gratuito) — `render.yaml`
- **URL:** `https://proyecto5-grupo1.onrender.com`

### Endpoints

| Método | Endpoint | Descripción |
|---|---|---|
| GET | `/` | Estado del servicio |
| GET | `/health` | Health check |
| POST | `/predict` | Recibe datos de sensores, devuelve resultado de detección |
| GET | `/app/latest-version` | Versión APK más reciente (OTA) |
| POST | `/app/register-version` | Registra nueva versión (CI) |

### Estructura `Backend/`

```
Backend/
├── api/main.py              ← API FastAPI
├── ml/                      ← entrenamiento, modelos .pkl
├── notebooks/               ← EDA
├── data/raw/                ← datasets crudos
├── data/processed/          ← CSVs y eda_output/
├── Dockerfile
└── requirements.txt
```

### Conexión Flutter ↔ Backend

- Controlado por `_useMock` en `Frontend/lib/services/api_service.dart`
- `true` → mock local (desarrollo offline)
- `false` → API real en Render *(configuración actual)*

---

## 9. Escalado futuro

- Soporte para smartwatch como dispositivo principal de monitorización
- App separada para cuidadores
- Más funcionalidades por definir
