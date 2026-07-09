# EDA SisFall - SL-13

## Cobertura

- Ensayos procesados: 4396
- Archivos crudos analizados: 4396
- Sujetos: 38
- Caidas: 1744
- ADL: 2652
- Frecuencia documentada: 200 Hz

## Evidencias generadas

- Balance de clases: `class_balance.csv`, `activity_balance.csv`.
- Histogramas X/Y/Z: `signal_xyz_histograms.png`.
- Correlacion: `correlation_heatmap.png`, `feature_correlation.csv`.
- Sesgo edad/sexo: `analisis_sesgo.md`, `bias_by_age_sex.csv`.
- Frecuencia de muestreo: `sampling_frequency_by_activity.csv`, `raw_trial_inventory.csv`.
- Fuga de datos: `single_feature_auc_scan.csv`.
- Consistencia raw/procesado: `data_consistency.md`.

## Notas para las siguientes tareas

- SL-14 debe fijar una ventana compartida entrenamiento/inferencia/app partiendo de 200 Hz nativo y del submuestreo objetivo movil.
- SL-17/SL-18 deben usar split por sujeto; no mezclar ensayos del mismo sujeto entre train y validacion.
- El sesgo de caidas simuladas por adultos jovenes queda documentado y no invalida SisFall.
