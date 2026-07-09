# Consistencia raw vs processed

## Resumen

- Filas en `sisfall_dataset.csv`: 4396.
- Claves unicas en `sisfall_dataset.csv`: 4391.
- Archivos crudos validos encontrados: 4396.
- Claves unicas en crudo local: 4391.
- Claves del procesado que no existen en crudo local: 0.
- Claves del crudo local que no existen en procesado: 0.
- Filas duplicadas en procesado por clave actividad/sujeto/rep: 10.
- Archivos crudos duplicados por clave actividad/sujeto/rep: 10.

## Interpretacion

El CSV procesado fue regenerado desde el crudo local y ya no hay claves faltantes entre `raw/sisfall/` y `processed/sisfall/sisfall_dataset.csv`.

Persisten duplicados por clave actividad/sujeto/rep. En el crudo local destacan `D17_SE15_R01..R05`, que aparecen tanto bajo `raw/sisfall/SA15/` como bajo `raw/sisfall/SE15/`.

## Archivos de detalle

- `processed_keys_missing_in_raw.csv`
- `raw_keys_missing_in_processed.csv`
- `processed_duplicate_keys.csv`
- `raw_duplicate_keys.csv`
