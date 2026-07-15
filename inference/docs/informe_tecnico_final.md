# Informe Técnico Final — SentiLife
**Factoría F5 Madrid · Grupo 1 · Nivel Experto**  
Fecha: 14/07/2026 · Dataset: SisFall · Contrato ventana: v1.0.0

> Documento consolidado (v1 → v2 → v3 + MLOps). Versiones anteriores: `informe_tecnico_v1.md`, `v2.md`, `v3.md`.

---

## 1. Resumen ejecutivo

SentiLife detecta caídas en tiempo real a partir de telemetría IMU (acelerómetro + giroscopio) con un pipeline end-to-end: **Flutter → Spring Boot → FastAPI → XGBoost**, con alertas push al cuidador y ciclo MLOps completo (retrain, drift, A/B, promoción automática).

| Hito | Métrica clave | Estado |
|---|---|---|
| Modelo producción | XGBoost `xgboost-v1.1.0-mobile-aligned` | ✅ ACTIVE |
| Recall caída (test) | **0.890** | ✅ priorizada |
| Overfitting train→test | **2.98 pp** (< 5%) | ✅ |
| LOSO PR-AUC | **0.925** | ✅ |
| Paridad móvil ↔ SisFall | 0 FP en `adl_replay` (3/3) | ✅ T2c.5 |
| Latencia E2E local | 61–197 ms | ✅ |
| MLOps retrain real | POST `/train` + promoción por recall | ✅ T4.4 |
| Data drift PSI | Grafana + alerta > 0.2 | ✅ T4.7 |
| CNN 1D vs XGBoost | XGBoost gana LOSO (+12.4 pp) | ✅ T4.2 |

---

## 2. Dataset, sesgo y metodología

### 2.1 SisFall (DS-01)

- **38 sujetos** (23 adultos, 15 mayores) · **4.396 ensayos** · **56.313 ventanas**
- Caídas simuladas en laboratorio — limitación documentada
- Referencia EDA: `data/processed/sisfall/eda_output/`

### 2.2 Sesgo documentado

| Grupo | Caídas | Observación |
|---|---|---|
| Adultos (F/M) | 844 / 825 | ~49% tasa caída |
| Mayores (F) | 0 | Sin ensayos de caída |
| Mayores (M) | 75 | Subrepresentados |

**Implicación:** el modelo puede sobreajustarse a patrones de adultos jóvenes. Mitigación: split **siempre por sujeto** (GroupKFold/LOSO) y recall priorizada sobre accuracy.

Detalle: `data/processed/sisfall/eda_output/analisis_sesgo.md`

### 2.3 Contrato de ventana (ADR-05)

| Parámetro | Valor |
|---|---|
| Duración | 2,5 s |
| Frecuencia | 50 Hz |
| Muestras | 125 |
| Solape | 50% |
| Features | 116 estadísticas |
| Archivo | `contracts/window_contract.json` v1.0.0 |

### 2.4 Split por sujeto

```
Train:      41.307 ventanas (26 sujetos)   70%
Validation:  6.713 ventanas (6 sujetos)    15%
Test:        8.293 ventanas (6 sujetos)    15%
```

Sin fuga entre sujetos. Sin SMOTE (ventanas son resúmenes estadísticos).

---

## 3. Evolución del modelo

### 3.1 Baseline (T1 — v1)

| Modelo | PR-AUC test | Recall caída | Overfitting |
|---|---|---|---|
| XGBoost | **0.901** | **0.832** | 2.2 pp ✅ |
| Random Forest | 0.880 | 0.728 | 2.1 pp ✅ |

Artefacto: `ml/models/model.pkl` · Informe: `informe_tecnico_v1.md`

### 3.2 Ensembles + Optuna (T2 — v2)

| Paso | Resultado |
|---|---|
| Comparativa RF/GB/XGBoost | XGBoost LOSO **0.925** |
| Optuna tuning | test PR-AUC **0.916** |
| Artefacto | `ml/models/model_tuned.pkl` |

Informe: `informe_tecnico_v2.md` · `ml/artifacts/ensemble_comparison.json`, `optuna_study.json`

### 3.3 Alineación móvil (T2c.5)

| Métrica | Valor |
|---|---|
| Versión | `xgboost-v1.1.0-mobile-aligned` |
| Umbral | 0.35 |
| Recall test | **0.890** |
| Precision test | 0.739 |
| F1 test | 0.808 |
| PR-AUC test | 0.914 |
| ADL replay | **0/3 FP** |

Causa raíz paridad: `GRAVITY_AXIS` + `PEAK_SHAPE` → `gravity_align.py`  
Artefacto: `ml/artifacts/t2c5_metrics.json` · Informe: `informe_paridad_movil_sisfall.md`

---

## 4. Nivel Experto — MLOps

### 4.1 Registry de modelos (T4.3)

- `ml/registry/registry.json` — estados ACTIVE / CANDIDATE / RETIRED
- FastAPI: `GET /model/registry`, `POST /model/reload`
- Hot-reload sin reiniciar contenedor

### 4.2 A/B Testing (T4.6)

- `ABTestingService`: 80% ACTIVE / 20% CANDIDATE
- Prometheus: `ab_testing_predictions_total{model_status}`
- Panel Grafana en `sentilife-pipeline.json`

### 4.3 CNN 1D vs XGBoost (T4.2)

| Modelo | Test PR-AUC | Recall | LOSO PR-AUC | Overfitting |
|---|---|---|---|---|
| XGBoost (mismo split) | **0.891** | **0.813** | **0.925** | 2.98 pp ✅ |
| CNN 1D | 0.862 | 0.760 | 0.801 | 1.36 pp ✅ |

**Decisión:** XGBoost mantiene producción. CNN documentada como experimento ML-15.  
Artefacto: `ml/models/cnn1d-v1.0.0.keras` · `ml/artifacts/cnn1d_comparison.json`

### 4.4 Reentrenamiento automático (T4.4 / T4d / RF-33 / RF-45)

Pipeline: `DRIFT → TRAINING → EVALUATING → DECIDING → COMPLETED`

| Criterio | Umbral |
|---|---|
| **Mínimo feedback** para arrancar job | **5** registros etiquetados válidos (Postgres) |
| **Recomendado** | **10** registros (diversidad caídas + falsas alarmas) |
| Promoción: recall nuevo > recall ACTIVE | obligatorio |
| Promoción: overfitting ≤ 5% | obligatorio |

- **T4d:** `RetrainService` exporta Postgres → body `feedback_rows` → `POST /train` (sin CSV manual). Verificado `augmented_windows ≥ 1` en T4d.INT.
- Script: `ml/training/retrain_feedback.py` · Endpoint: `POST /train`
- UI IT: pestaña MLOps — contador feedback, panel criterios, modal si insuficiente, confirmación antes de lanzar
- Ayuda por perfil (RF-44): botón `?` en MONITORED / CAREGIVER / IT_ADMIN

Última ejecución documentada: `ml/artifacts/retrain_metrics.json` · acta `docs/daily/t4dint-feedback-retrain-20260715.md`

### 4.5 Data Drift (T4.7 / ML-18)

| Componente | Detalle |
|---|---|
| Métrica | PSI medio (40 features) vs baseline SisFall |
| Umbral | 0.2 (`DRIFT_PSI_THRESHOLD`) |
| Buffer | 500 ventanas producción en `/predict` |
| Endpoints | `GET /drift` · `POST /drift/recompute` |
| Prometheus | `feature_drift_psi`, `feature_drift_detected`, `feature_drift_samples` |
| Grafana | gauge + timeseries + alerta `sentilife-drift-psi` |
| Retrain | fase DRIFT → HTTP real a `/drift/recompute` |

---

## 5. Arquitectura de producción

```
Flutter (3 roles) → Spring Boot (JWT, negocio) → FastAPI (inferencia)
                         ↓                              ↓
                    PostgreSQL                    ml/models/*.pkl
                    RabbitMQ → FCM push           ml/registry/
                         ↓
              Prometheus → Grafana (latencia, A/B, drift, colas)
```

- **6 servicios** dockerizados: db, rabbitmq, backend, api, prometheus, grafana
- **0 mocks** en `frontend/lib/` — solo backend Java real
- Tests (15/07): mvn ✅ · pytest **54** passed (4 skipped) · flutter **114** passed

---

## 6. Criterios de aceptación Factoría

| Nivel | Requisito | Evidencia |
|---|---|---|
| 🟢 Esencial | Modelo + FastAPI + informe v1 | T1.INT smoke |
| 🟡 Medio | Ensembles + Optuna + feedback | T2.INT smoke-mvp |
| 🟠 Avanzado | Docker + CI/CD + tests + GDPR + OTA | T3.INT smoke-qa-ec2 |
| 🔴 Experto | CNN + MLOps + drift + A/B + retrain DB | T4.INT + T4d.INT |
| 🟣 Post-demo | Push completo, export auth, Grafana, ayuda UX | T5.1–T5.6 |

---

## 7. Limitaciones y trabajo futuro

1. **Sesgo de edad** en SisFall — validar con datos de mayores reales
2. **MobiAct** cortado (CEMP) — no usado en Factoría
3. **Retrain** job state in-memory — persistir en DB para resiliencia post-Factoría
4. **QA campo pendiente:** certificación 10 min pantalla bloqueada Android (protocolo en `docs/daily/t2c11-android-background-qa-20260715.md`, ejecución jue 16)
5. **CORS abierto en EC2** — endurecer post-demo

---

## 8. Referencias de artefactos

| Archivo | Contenido |
|---|---|
| `ml/artifacts/ensemble_comparison.json` | RF/GB/XGBoost LOSO |
| `ml/artifacts/optuna_study.json` | Hiperparámetros óptimos |
| `ml/artifacts/t2c5_metrics.json` | Modelo móvil alineado |
| `ml/artifacts/cnn1d_comparison.json` | CNN vs XGBoost |
| `ml/artifacts/retrain_metrics.json` | Último retrain |
| `ml/artifacts/drift_baseline.json` | Baseline PSI |
| `docs/daily/t4int-expert-demo-20260714.md` | Acta demo experto |

---

*SentiLife · Grupo 1 · Factoría F5 Madrid · Julio 2026*
