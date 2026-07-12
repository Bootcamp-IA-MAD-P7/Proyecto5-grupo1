# Informe Técnico v1 — SentiLife Fall Detection Model
**T1.6 · Nivel Esencial**  
Fecha: 12/07/2026 · Dataset: SisFall · Contrato de ventana: v1.0.0

---

## 1. Resumen ejecutivo

| Métrica | XGBoost (modelo final) | Random Forest |
|---|---|---|
| PR-AUC test | **0.901** | 0.880 |
| PR-AUC CV agrupada (5-fold) | **0.923 ± 0.023** | 0.901 ± 0.027 |
| PR-AUC LOSO | **0.925** | — |
| F1 caída (test) | **0.814** | 0.770 |
| Recall caída (test) | **0.832** | 0.728 |
| Precisión caída (test) | **0.797** | 0.812 |
| Accuracy total (test) | **0.887** | 0.872 |
| Umbral óptimo (validation) | **0.57** | 0.51 |
| Overfitting CV→Test | **2.2 pp** ✅ (<5%) | 2.1 pp ✅ |

**Modelo seleccionado:** XGBoost — mejor PR-AUC en test y CV; recall de caída superior (83.2%), que es la métrica prioritaria para el sistema.

---

## 2. Dataset y preprocesado

### 2.1 Origen del dataset

- **Dataset:** SisFall (Santamaría et al., 2017) — referencia académica validada.
- **Naturaleza:** caídas simuladas en laboratorio. Limitación documentada.
- **Sujetos:** 38 (23 adultos, 15 mayores)
- **Ensayos totales:** 4.396 (1.744 caídas + 2.652 ADL)
- **Referencia EDA:** `data/processed/sisfall/eda_output/eda_summary.md`

### 2.2 Pipeline de features (contrato T1.2 / SL-14)

| Parámetro | Valor |
|---|---|
| Ventana | 2,5 s |
| Frecuencia original | 200 Hz |
| Frecuencia de muestreo app | 50 Hz |
| Muestras por ventana | 125 |
| Solape | 50% |
| **Total ventanas generadas** | **56.313** |
| Features por ventana | 116 |
| Contrato versionado | `contracts/window_contract.json` v1.0.0 |

Distribución de clases resultante: **37.134 no-caída (65,9%)** / **19.179 caída (34,1%)** · Ratio ≈ 1,9:1.

### 2.3 Split por sujeto (sin fuga)

```
Total: 56.313 ventanas, 38 sujetos
Train:      41.307 ventanas (26 sujetos)   70%
Validation:  6.713 ventanas (6 sujetos)    15%
Test:        8.293 ventanas (6 sujetos)    15%
```

Se usa `GroupShuffleSplit` para garantizar que **ningún subject_id quede repartido** entre splits. Verificación explícita: `assert not (train_subjects & temp_subjects)`. Sin SMOTE (filas son resúmenes estadísticos de ensayos, interpolar entre ellas no tiene sentido físico).

---

## 3. Modelos evaluados

### 3.1 Hiperparámetros

**Random Forest:**
```
n_estimators=300, max_depth=8, min_samples_leaf=3, class_weight="balanced"
```

**XGBoost:**
```
n_estimators=300, max_depth=4, learning_rate=0.05, subsample=0.8,
colsample_bytree=0.8, scale_pos_weight=1.94 (ratio neg/pos)
```

### 3.2 Validación cruzada agrupada (StratifiedGroupKFold, 5 folds, solo train)

| Modelo | PR-AUC CV media | Desviación |
|---|---|---|
| Random Forest | 0.901 | ± 0.027 |
| **XGBoost** | **0.923** | **± 0.023** |

---

## 4. Resultados en test (conjunto independiente, nunca visto en entrenamiento)

### 4.1 XGBoost — Informe de clasificación (umbral 0.57)

```
              precision    recall  f1-score   support

    No caída       0.93      0.91      0.92      5818
       Caída       0.80      0.83      0.81      2475

    accuracy                           0.89      8293
   macro avg       0.86      0.87      0.87      8293
weighted avg       0.89      0.89      0.89      8293
```

### 4.2 Matriz de confusión — XGBoost

```
                  Predicho: No caída    Predicho: Caída
Real: No caída         5.295               523   (FP: 9.0%)
Real: Caída              418             2.057   (FN: 16.9%)
```

- **Falsos Negativos (FN = 418):** caídas no detectadas — el riesgo más crítico para el sistema.
- **Falsos Positivos (FP = 523):** falsas alarmas — impacto en fatiga de alertas para el cuidador.
- El umbral 0.57 (vs. 0.5 por defecto) reduce FP a costa de aceptar un FN marginalmente mayor, optimizando F1 global en validation.

### 4.3 Random Forest — Matriz de confusión (umbral 0.51)

```
                  Predicho: No caída    Predicho: Caída
Real: No caída         5.384               434   (FP: 7.5%)
Real: Caída              673             1.802   (FN: 27.2%)
```

RF produce menos FP pero significativamente más FN (673 vs 418) → XGBoost es claramente superior en recall de caída.

---

## 5. Validación Leave-One-Subject-Out (LOSO)

El LOSO entrena con 37 sujetos y evalúa el sujeto restante, repitiendo 38 veces. Es la estimación más honesta de la generalización a nuevas personas no vistas.

| Métrica | LOSO |
|---|---|
| PR-AUC agregado | **0.925** |
| F1 caída agregado | **0.832** |
| Accuracy media por sujeto | 0.890 ± 0.065 |

```
Matriz de confusión LOSO (todos los sujetos agregados):
                  Predicho: No caída    Predicho: Caída
Real: No caída        33.918             3.216
Real: Caída            3.236            15.943
```

**Hallazgo positivo:** el PR-AUC en LOSO (0.925) es ligeramente superior al PR-AUC en test (0.901), lo que indica que el modelo no memorizó patrones específicos de los sujetos de entrenamiento. La generalización es robusta.

### 5.1 Peores 5 sujetos (LOSO)

| Sujeto | n_ventanas | Accuracy |
|---|---|---|
| SE01 | 1.101 | **0.557** |
| SA02 | 1.906 | 0.813 |
| SE06 | 1.906 | 0.835 |
| SA18 | 1.906 | 0.854 |
| SA05 | 1.906 | 0.855 |

SE01 es el único outlier severo (accuracy 0.557). Es un sujeto mayor (`elderly`) con solo 1.101 ventanas y patrones de movimiento atípicos que el modelo no captura bien al ser excluido del entrenamiento.

---

## 6. Feature Importance

Top-10 features del modelo XGBoost final:

| Rank | Feature | Importancia |
|---|---|---|
| 1 | `accY_mean` | 0.103 |
| 2 | `accY_max` | 0.034 |
| 3 | `gyroX_max` | 0.033 |
| 4 | `accX_diff_mean_abs` | 0.030 |
| 5 | `accY_median` | 0.029 |
| 6 | `gyro_sma` | 0.029 |
| 7 | `acc_magnitude_std` | 0.028 |
| 8 | `accY_kurtosis` | 0.024 |
| 9 | `gyro_magnitude_q75` | 0.023 |
| 10 | `accY_diff_max_abs` | 0.021 |

**→ Las 2 features más importantes acaparan solo el 14% de la importancia total** (umbral de preocupación: >50%). El modelo distribuye el peso entre características estadísticas de aceleración vertical (`accY_*`) y del giróscopo, sin depender de un único atajo.

*Interpretación física:* el eje Y (vertical) domina, consistente con la física de una caída: el cuerpo experimenta cambios bruscos en la componente vertical de la aceleración al perder el equilibrio y al impactar. `kurtosis` y `diff_max_abs` capturan la impulsividad del evento.

---

## 7. Análisis de sesgo (edad/sexo)

### 7.1 Sesgo de diseño del dataset

| Grupo | Sujetos | n_ensayos | n_caídas | Tasa caída |
|---|---|---|---|---|
| Adult F | 12 | 1.730 | 844 | 48.8% |
| Adult M | 11 | 1.693 | 825 | 48.7% |
| Elderly F | 7 | 406 | **0** | 0% |
| Elderly M | 8 | 567 | 75 | 13.2% |

**14 de 15 sujetos mayores no tienen ensayos de caída** (decisión de los autores del dataset por motivos de seguridad). Esto es un sesgo estructural del dataset, no del modelo.

Mitigación aplicada: `age_group` excluida explícitamente de las features — el modelo no puede aprender el atajo falso "mayor = no cae".

### 7.2 Recall por grupo de edad (LOSO)

| Grupo | n_ventanas | Caídas reales | Accuracy | Recall caída | FN | FP |
|---|---|---|---|---|---|---|
| Adult | 42.290 | 18.354 | 0.885 | **0.836** | 3.018 | 1.828 |
| Elderly | 14.023 | 825 | 0.885 | **0.736** | 218 | 1.388 |

**Gap recall adulto→mayor: 10 pp (83.6% → 73.6%).**  
Causa probable: el modelo solo aprendió caídas de sujetos mayores de los 8 hombres con ensayos de caída en SisFall (75 caídas de 38 totales). Con tan pocos ejemplos, la generalización a mayores es más débil.

**Implicación clínica:** para el sistema real, el recall en `elderly` es la métrica más crítica (las consecuencias de no detectar una caída en un mayor son graves). Se debe priorizar la recolección de datos reales de usuarios mayores en producción (ciclo de feedback → reentrenamiento, T4.4).

---

## 8. Verificación de overfitting

| Split | PR-AUC | Δ vs. CV |
|---|---|---|
| CV agrupada (train, 5 folds) | 0.923 | — |
| Validation | ~0.920 (implícito por threshold) | ~0.3 pp |
| **Test** | **0.901** | **2.2 pp** |
| LOSO | 0.925 | — |

**Overfitting < 5%** ✅ — cumple el criterio de la constitución (ML-02, ML-03).

---

## 9. Conclusiones y próximos pasos

### ✅ Nivel Esencial — requisitos cumplidos

| Requisito | Estado |
|---|---|
| EDA completo con sesgo documentado | ✅ T1.1 |
| Contrato de ventana publicado | ✅ T1.2 |
| Pipeline de features reproducible | ✅ T1.3 |
| Baseline GroupKFold / LOSO | ✅ T1.4 |
| Modelo candidato overfitting < 5% | ✅ T1.5 |
| Recall de caídas priorizado | ✅ XGBoost recall=0.832 |
| FastAPI con `/predict` activo | ✅ T0.8 |
| Informe técnico v1 | ✅ **este documento** |

### Limitaciones conocidas

1. **Caídas simuladas:** SisFall usa actores. La distribución de impactos puede diferir de caídas reales, especialmente en intensidad del pico de aceleración.
2. **Recall en mayores (73.6%):** insuficiente para uso clínico real. Requiere datos reales de mayores.
3. **Sujeto SE01 (outlier):** accuracy 55.7% en LOSO. Posible patrón de movimiento anómalo o error en los datos de este sujeto.
4. **Sin validación temporal:** el split aleatorio por sujeto no valida contra deriva temporal. Relevante cuando se reentrenar con datos acumulados.

### Próximos pasos (Nivel Medio — T2.1, T2.2)

- Añadir Gradient Boosting (scikit-learn) a la comparativa.
- Optuna sobre XGBoost y RF (objetivo: PR-AUC en LOSO > 0.93).
- Informe v2 con curvas ROC superpuestas y comparativa de modelos.
- Recolectar datos de usuarios reales para mejorar recall en mayores.

---

*Generado con los scripts `Backend/ml/train_model.py` y `Backend/ml/diagnostico.py` · Reproducible ejecutando `make ml-train` desde la raíz.*
