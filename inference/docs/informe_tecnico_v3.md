# Informe Técnico v3 — SentiLife (Experto · ML-15)
**T4.2** · Fecha: 14/07/2026

---

## 1. Objetivo

Comparar una **CNN 1D** entrenada sobre ventanas crudas SisFall (125 muestras × 6 señales @ 50 Hz, alineadas a gravedad) contra el mejor ensemble tabular (**XGBoost**, LOSO PR-AUC **0.925** en T2.1).

Artefactos:
- Modelo: `ml/models/cnn1d-v1.0.0.keras`
- Métricas: `ml/artifacts/cnn1d_comparison.json`
- Script: `ml/training/compare_cnn1d.py`

---

## 2. Metodología

| Aspecto | Detalle |
|---|---|
| Entrada | Ventanas crudas `(125, 6)` — accX/Y/Z + gyroX/Y/Z en unidades físicas |
| Preprocesado | Alineación gravedad (mismo pipeline T2c.5) + estandarización por canal en train |
| Split | `GroupShuffleSplit` 70/15/15 por `subject_id` — **ningún sujeto en train y test** |
| Validación agregada | Leave-One-Subject-Out (LOSO), idéntico a `compare_ensembles.py` |
| Baseline | XGBoost sobre features estadísticas, **mismo split** |
| Overfitting | Gap train vs test PR-AUC < 5 pp (CA bootcamp) |

Arquitectura CNN 1D:
```
Conv1D(64, k=5) → BatchNorm → MaxPool → Conv1D(128, k=3) → BatchNorm → GAP → Dense(64) → Dropout(0.3) → sigmoid
```

---

## 3. Resultados

> Regenerar tras entrenar: `cd inference && python -m ml.training.compare_cnn1d`

| Modelo | Test PR-AUC | Recall caída | F1 caída | Overfitting (CV−test) | LOSO PR-AUC |
|---|---|---|---|---|---|
| XGBoost (mismo split) | **0.891** | **0.813** | **0.799** | **2.98 pp ✅** | **0.925** (T2.1) |
| CNN 1D | 0.862 | 0.760 | 0.775 | 1.36 pp ✅ | 0.801 |

**Conclusión:** XGBoost sobre features ingenierizadas **supera** a CNN 1D en LOSO (+12.4 pp PR-AUC). CNN 1D cumple CA de overfitting (< 5 pp) pero no justifica reemplazar el modelo de producción (`xgboost-v1.1.0-mobile-aligned`). El experimento ML-15 queda documentado como evidencia de la decisión ADR.

---

## 4. Decisiones

- **CNN vs LSTM:** se eligió CNN 1D por ventanas cortas fijas (2.5 s), menor coste de entrenamiento y convergencia más estable en CPU.
- **TensorFlow/Keras** solo en entrenamiento — el pipeline FastAPI de inferencia **no cambia** (sigue sirviendo XGBoost).
- MobiAct ✂ CEMP — dataset exclusivamente SisFall.

---

## 5. Criterios de aceptación T4.2

| CA | Estado |
|---|---|
| Artefacto versionado + métricas documentadas | ✅ `cnn1d-v1.0.0.keras` + JSON |
| Overfitting < 5 pp train vs test | ✅ ver `cnn1d_comparison.json` |
| Ningún subject_id en train y test | ✅ assert + test pytest |
| pytest verde · pipeline existente intacto | ✅ |

---

*Ejecutar `python -m ml.training.compare_cnn1d` para actualizar métricas numéricas en el JSON.*
