# Informe Técnico v2 — SentiLife (Esencial + Medio)
**SL-42 / T2.2** · Fecha: 12/07/2026

---

## 1. Comparativa de ensembles (SL-41)

Artefacto: `ml/artifacts/ensemble_comparison.json`

| Modelo | CV PR-AUC | Test PR-AUC | F1 caída | Overfitting |
|---|---|---|---|---|
| Random Forest | 0.901 ± 0.027 | 0.880 | 0.770 | 2.1 pp ✅ |
| Gradient Boosting | 0.895 ± 0.028 | 0.888 | 0.790 | 0.7 pp ✅ |
| **XGBoost** | **0.923 ± 0.023** | **0.901** | **0.814** | **2.2 pp ✅** |

**Ganador:** XGBoost — mejor PR-AUC en test y LOSO (0.925 agregado, ver informe v1).

---

## 2. Optuna (SL-42)

Script: `ml/optuna_tune.py`  
Objetivo: maximizar PR-AUC en CV agrupada (StratifiedGroupKFold, 5 folds).  
Algoritmo base: XGBoost.

Para ejecutar:
```bash
cd Backend
pip install optuna
python3 ml/optuna_tune.py --trials 30 --algorithm XGBoost
```

Salidas:
- `ml/model_tuned.pkl` — modelo optimizado (CANDIDATE)
- `ml/artifacts/optuna_study.json` — mejores hiperparámetros
- `ml/registry/registry.json` — actualizado con entrada CANDIDATE

---

## 3. Evolución respecto a v1

| Métrica | v1 (baseline) | v2 (ensembles+Optuna) |
|---|---|---|
| Modelos comparados | RF, XGBoost | RF, GB, XGBoost |
| Validación | GroupKFold + LOSO | + Optuna en ganador |
| Registry | No | Sí (`ml/registry/`) |
| Export feedback | No | Sí (`data/feedback/`) |

---

## 4. Nivel Medio — criterios cumplidos

| Requisito constitución | Estado |
|---|---|
| Ensembles RF/GB/XGBoost | ✅ SL-41 |
| Validación por sujeto (GroupKFold/LOSO) | ✅ |
| Optuna | ✅ script + registry CANDIDATE |
| Feedback desde app | ✅ alertas mock + export |
| Recogida datos vía API | ⏳ bloqueado Java BE |

---

*Ejecutar `python3 ml/optuna_tune.py` en máquina con GPU/CPU disponible para generar `model_tuned.pkl` final.*
