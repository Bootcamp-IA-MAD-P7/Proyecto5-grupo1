# Backend — Fall-Sentinel

API REST (FastAPI), pipeline de ML y EDA para clasificación de telemetría (Caída vs. ADL).

## Estructura

```
Backend/
├── main.py                  # API FastAPI (predict, app versioning)
├── Dockerfile                 # Despliegue en Render
├── requirements.txt
├── build_sisfall_dataset.py   # Convierte .txt crudos SisFall → CSV
├── eda_sisfall.py             # Análisis exploratorio (genera eda_output/)
├── train_model.py             # Entrenamiento RandomForest / XGBoost
├── diagnostico.py             # Diagnóstico de sesgo y feature importance
├── model.pkl                  # Modelo baseline
├── model_ablation.pkl         # Modelo sin features shortcut
├── data/
│   ├── sisfall_dataset.csv    # Dataset principal (una fila por ensayo)
│   └── fall_detection_dataset.csv
└── eda_output/                # Gráficos y análisis de sesgo
```

## Dataset

**SisFall** — datos de acelerómetro y giroscopio de adultos mayores y adultos jóvenes simulando caídas y ADL.

Para regenerar el CSV desde archivos crudos:

```bash
python build_sisfall_dataset.py --root /ruta/a/SisFall --out data/sisfall_dataset.csv
```

## Pipeline ML

```bash
# 1. EDA
python eda_sisfall.py --data data/sisfall_dataset.csv

# 2. Entrenar
python train_model.py --data data/sisfall_dataset.csv

# 3. Diagnóstico
python diagnostico.py --data data/sisfall_dataset.csv
```

## API local

```bash
uvicorn main:app --reload --port 8000
```

Variables de entorno en producción (Render): `SUPABASE_URL`, `SUPABASE_KEY`.
