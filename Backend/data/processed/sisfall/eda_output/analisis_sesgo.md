# Análisis de sesgo — Sistema de detección de caídas (SisFall)

## 1. Contexto y objetivo

El dataset SisFall fue construido a partir de 4.505 ensayos de 38 sujetos, procesados en `sisfall_dataset.csv` mediante `build_sisfall_dataset.py`. El objetivo de este análisis es documentar de forma explícita dos hallazgos que surgieron durante la validación del modelo (XGBoost, PR-AUC 0.987 en split simple) y que no son visibles si solo se reporta la métrica agregada:

1. Un desbalance estructural entre adultos jóvenes y adultos mayores, propio del diseño experimental de SisFall.
2. Una posible dependencia del modelo en un "atajo" de feature engineering (magnitud máxima de acelerómetro/giroscopio).

Ambos se investigaron con evidencia empírica, no solo con inspección visual, y las conclusiones finales corrigen la hipótesis inicial.

---

## 2. Composición del dataset

| | Total | Caídas | No caídas | % caídas |
|---|---|---|---|---|
| **Global** | 4.505 | 1.798 | 2.707 | 39.9% |
| **Adultos jóvenes (adult)** | 3.532 | 1.723 | 1.809 | 48.8% |
| **Adultos mayores (elderly)** | 973 | 75 | 898 | 7.7% |

**Hallazgo clave:** de los 38 sujetos, **14 (todos del grupo "SE", adultos mayores) no tienen ni un solo ensayo de caída registrado**. Esto no es un artefacto del pipeline de procesamiento — es una decisión del diseño original de SisFall: por motivos de seguridad, no se pidió a la mayoría de los participantes mayores que simularan caídas.

**Consecuencia directa:** el modelo aprende el patrón "caída" casi exclusivamente de sujetos jóvenes simulando el evento, mientras que la población objetivo real de un sistema de detección de caídas son personas mayores — exactamente el grupo peor representado en los datos de la clase positiva.

---

## 3. Primer diagnóstico: ¿el modelo depende de un atajo?

### 3.1 Detector de fuga por AUC individual

Se evaluó qué tan bien separa cada feature, por sí sola, la clase "caída" de "no caída":

| Feature | AUC individual |
|---|---|
| `acc1_magnitude_max` | 0.934 ⚠ |
| `gyro_magnitude_max` | 0.926 ⚠ |
| `acc1_jerk_max` | 0.916 ⚠ |
| `gyro_magnitude_std` | 0.893 ⚠ |
| `acc1_magnitude_std` | 0.832 |
| `acc1_jerk_mean` | 0.778 |
| `acc1_magnitude_min` | 0.745 |
| `gyro_magnitude_mean` | 0.600 |
| `acc1_magnitude_mean` | 0.557 |
| `gyro_magnitude_min` | 0.554 |

Ninguna alcanza el umbral de fuga evidente (AUC > 0.95, como ocurrió en una iteración previa con una feature `n_samples` descartada), pero 4 features superan 0.85, lo cual amerita revisión.

### 3.2 Feature importance del modelo final (XGBoost)

```
gyro_magnitude_max   0.360  ██████████████████
acc1_magnitude_max   0.209  ██████████
gyro_magnitude_std   0.089  ████
acc1_jerk_max         0.067  ███
...
```

**Las 2 features más importantes acaparan el 57% de la importancia total del modelo.** Esto sugirió inicialmente que el modelo podía estar aprendiendo un umbral simple de magnitud de impacto, en vez de un patrón robusto de la dinámica del movimiento.

### 3.3 Experimento de ablation

Para probar la hipótesis del atajo, se entrenó un segundo modelo excluyendo explícitamente `acc1_magnitude_max` y `gyro_magnitude_max`, y se comparó contra el modelo baseline en LOSO (Leave-One-Subject-Out, 38 folds, un sujeto completo excluido por fold).

| Métrica | Baseline (con magnitud máx.) | Ablation (sin magnitud máx.) | Δ |
|---|---|---|---|
| PR-AUC global | 0.983 | 0.969 | −0.014 |
| F1 global | 0.942 | 0.926 | −0.016 |
| Recall — adult | 0.967 | 0.945 | −0.022 |
| **Recall — elderly** | **0.747** | **0.760** | **+0.013** |
| FN elderly | 19 | 18 | −1 |
| FP elderly | 34 | 47 | +13 |

**Conclusión del ablation:** quitar las features de magnitud máxima **no mejora el recall en población mayor** (diferencia de +0.013, dentro del ruido estadístico con solo 75 casos positivos). Lo único que produce es una pequeña pérdida de rendimiento general, sobre todo en adultos jóvenes, y más falsos positivos en ambos grupos.

**Esto descarta la hipótesis inicial.** El atajo de magnitud máxima es una feature fuerte para el grupo mejor representado (adultos jóvenes) pero no es la causa de la brecha de rendimiento en adultos mayores. Es un hallazgo relevante en sí mismo: la intuición de "una feature dominante = mal indicio" no siempre identifica correctamente la causa raíz de un problema de generalización.

---

## 4. Segundo diagnóstico: validación LOSO desglosada por edad

El diagnóstico agregado (LOSO sobre los 38 sujetos) da resultados aparentemente excelentes:

- PR-AUC: 0.983
- F1: 0.942
- Accuracy promedio por sujeto: 0.954 ± 0.044

Pero al desglosar por `age_group`, aparece la brecha real:

| Grupo | n ensayos | Caídas reales | Accuracy | **Recall caída** | FN | FP |
|---|---|---|---|---|---|---|
| Adult | 3.532 | 1.723 | 0.955 | **0.967** | 57 | 103 |
| **Elderly** | 973 | 75 | 0.946 | **0.747** | 19 | 34 |

**El modelo pierde 1 de cada 4 caídas reales de personas mayores** (recall 0.747 vs 0.967 en jóvenes — una brecha de 22 puntos). El accuracy global oculta esto porque la clase "no caída" en elderly es mayoritaria (898 de 973 ensayos) y el modelo la clasifica bien, inflando el accuracy agregado aunque falle en la clase que más importa.

### Nota sobre la fiabilidad estadística de este número

Con solo 75 caídas reales de mayores en todo el dataset (repartidas entre muy pocos sujetos, dado que 14 de 15 no tienen ninguna), el intervalo de confianza real de ese recall 0.747 es amplio. No es posible afirmar con precisión si el "verdadero" recall en población mayor es 0.65 o 0.85 — la muestra es demasiado pequeña. Lo que sí es robusto es la **dirección** del hallazgo: hay una brecha de rendimiento sustancial y consistente entre grupos, replicada tanto en el modelo baseline como en el de ablation.

---

## 5. Causa raíz

No es un problema de arquitectura de modelo ni de selección de features. Es un problema de **representación de datos**:

- 75 caídas de mayores frente a 1.723 de jóvenes (ratio ~23:1).
- 14 de 38 sujetos mayores no aportan ningún ejemplo positivo.
- SisFall usa caídas **actuadas** (simuladas de forma controlada), predominantemente por sujetos jóvenes, con picos de aceleración/giro probablemente más marcados que una caída real de una persona mayor en su vida diaria (tropiezo, pérdida de equilibrio gradual, desvanecimiento). Esto no se pudo confirmar directamente sin datos de caídas reales de referencia, pero es consistente con la literatura sobre datasets de caídas simuladas.

Ningún ajuste de hiperparámetros, regularización o selección de features puede compensar la ausencia casi total de señal positiva en el subgrupo objetivo.

---

## 6. Conclusiones y recomendaciones

1. **El modelo baseline (con todas las features) es el que se debe conservar para producción/entrega**, no el de ablation: tiene mejor rendimiento general y un recall en elderly estadísticamente equivalente.

2. **La detección de caídas en adultos mayores no debe considerarse resuelta con este dataset.** Un recall de 0.75 implica que, de cada 4 caídas reales de una persona mayor, el sistema no detecta 1 — el peor tipo de error posible en una aplicación de seguridad.

3. **Recomendaciones para llevar esto a producto real** (fuera del alcance de este análisis, pero relevantes):
   - Complementar el entrenamiento con datasets que incluyan más señal de caídas de población mayor (p. ej. FARSEEING, UMAFall, MobiAct).
   - No depender exclusivamente del clasificador de ML: combinarlo con capas adicionales (confirmación manual, detección de inmovilidad posterior al evento, contacto de emergencia con cuenta regresiva), como hacen los sistemas comerciales existentes.
   - Ajustar el umbral de decisión priorizando explícitamente minimizar falsos negativos sobre falsos positivos, dado el coste asimétrico de cada tipo de error en este dominio.

4. **Metodológicamente**, este caso ilustra por qué una métrica agregada (accuracy, PR-AUC) puede ocultar fallos importantes en subgrupos minoritarios, y por qué es necesario desglosar por variables demográficas relevantes antes de considerar un modelo listo para su uso — incluso cuando el número global parece excelente (PR-AUC 0.983 agregado vs 0.747 de recall en el subgrupo que más importa).

---

## Apéndice: reproducibilidad

- Dataset: `sisfall_dataset.csv` (generado por `build_sisfall_dataset.py`)
- Modelo baseline: `ml/model.pkl` — XGBoost, `python ml/train_model.py --data data/processed/sisfall/sisfall_dataset.csv`
- Modelo ablation: `ml/model_ablation.pkl` — `python ml/train_model.py --data data/processed/sisfall/sisfall_dataset.csv --drop-shortcut-features`
- Diagnóstico completo (feature importance + LOSO + desglose por edad): `python ml/diagnostico.py --data data/processed/sisfall/sisfall_dataset.csv --model ml/model.pkl`