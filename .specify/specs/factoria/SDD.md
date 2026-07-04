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
├── Frontend/          # App Flutter
├── Backend/           # FastAPI, ML, notebooks Kaggle, datasets
│   ├── api/
│   ├── ml/
│   ├── notebooks/     # EDA y experimentos Kaggle
│   └── data/raw/      # Dataset (Real-Time Patient Fall Detection Data)
├── docs/              # Daily standups y documentación operativa
└── .specify/          # Orquestación IA y especificaciones SDD (raíz)
    └── specs/factoria/  # intent → spec → plan → task
```

- **Frontend:** Flutter (Dart) — `Frontend/`
- **Backend:** FastAPI + Scikit-learn — `Backend/` *(pendiente de implementación)*
- **Detección actual:** Mock basado en umbrales de magnitud (temporal, hasta integrar dataset real)
- **Package ID:** `com.jzelada.proyecto_flutter`

### Archivos principales (`Frontend/lib/`)

```
Frontend/lib/
├── main.dart                          ← entrada, tema de la app
├── models/
│   └── prediction_result.dart         ← SensorSnapshot, FallDetectionResult
├── screens/
│   ├── home_screen.dart               ← monitorización en tiempo real
│   └── result_screen.dart             ← resultado del análisis / alerta de caída
└── services/
    └── api_service.dart               ← mock de sensores y clasificación
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

## 8. Escalado futuro

- Soporte para smartwatch como dispositivo principal de monitorización
- App separada para cuidadores
- Más funcionalidades por definir
