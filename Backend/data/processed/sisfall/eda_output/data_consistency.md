# Consistencia raw vs processed

## Resumen

- Filas en `sisfall_dataset.csv`: 4505.
- Claves unicas en `sisfall_dataset.csv`: 4500.
- Archivos crudos validos encontrados: 4396.
- Claves unicas en crudo local: 4391.
- Claves del procesado que no existen en crudo local: 109.
- Claves del crudo local que no existen en procesado: 0.
- Filas duplicadas en procesado por clave actividad/sujeto/rep: 10.
- Archivos crudos duplicados por clave actividad/sujeto/rep: 10.

## Interpretacion

El EDA queda generado, pero el crudo local no reproduce exactamente el CSV agregado actual. No se regenera `processed/sisfall/sisfall_dataset.csv` en SL-13 porque `Backend/data/README.md` indica que esa accion requiere decision del equipo.

Hallazgo principal: el CSV contiene claves de SA07 ausentes en el crudo local actual, y hay duplicados `D17_SE15_R01..R05` porque aparecen tanto bajo `raw/sisfall/SA15/` como bajo `raw/sisfall/SE15/`.

## Archivos de detalle

- `processed_keys_missing_in_raw.csv`
- `raw_keys_missing_in_processed.csv`
- `processed_duplicate_keys.csv`
- `raw_duplicate_keys.csv`
