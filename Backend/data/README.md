# Datasets — Fall-Sentinel

**Política del equipo:** todos los datasets van **en el repositorio**. Al clonar, cada miembro tiene los mismos datos sin pasos extra.

## Inventario

| ID | Fuente | Ubicación | En Git | Uso |
|---|---|---|---|---|
| **DS-01** | SisFall (crudo) | `raw/sisfall/` | Sí | Archivos `.txt` originales del ensayo |
| **DS-01b** | SisFall (procesado) | `processed/sisfall_dataset.csv` | Sí | Entrenamiento principal (4.506 ensayos) |
| **DS-02** | Kaggle — Real-Time Patient Fall Detection | `raw/kaggle/` | Sí | Dataset candidato PO (`zara2099/real-time-patient-fall-detection-data`) |
| **DS-03** | Sintético legacy | `processed/fall_detection_dataset.csv` | Sí | Deprecado — no usar en pipeline nuevo |

## DS-01 — SisFall

- **Crudo:** `raw/sisfall/` — archivos `<CODE>_<SUBJECT>_R<TRIAL>.txt`
- **Procesado:** generado con:

```bash
cd Backend
python ml/build_sisfall_dataset.py --root data/raw/sisfall --out data/processed/sisfall_dataset.csv
```

Fuente original: http://sisfall.imed.li/

## DS-02 — Kaggle

- **Slug:** `zara2099/real-time-patient-fall-detection-data`
- **URL:** https://www.kaggle.com/datasets/zara2099/real-time-patient-fall-detection-data
- **Carpeta:** `raw/kaggle/` — CSV/ZIP originales sin modificar

## DS-03 — Sintético (deprecado)

`processed/fall_detection_dataset.csv` — 1.000 filas generadas para prototipo Flutter. Mantener solo como referencia histórica.

## Regenerar processed desde crudo

Siempre que se actualice `raw/`, regenerar `processed/` y commitear ambos:

```bash
python ml/build_sisfall_dataset.py --root data/raw/sisfall --out data/processed/sisfall_dataset.csv
python notebooks/eda_sisfall.py
python ml/train_model.py
```
