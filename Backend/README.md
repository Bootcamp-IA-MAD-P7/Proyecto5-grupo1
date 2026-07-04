# Backend — Fall-Sentinel

API REST (FastAPI), pipeline de ML y notebooks para clasificación de telemetría (Caída vs. ADL).

## Estructura

```
Backend/
├── api/
│   ├── main.py              # FastAPI (entrada actual)
│   ├── inference/           # Carga de model.pkl y preprocesado (nivel Esencial+)
│   ├── routes/              # /predict, /feedback, /telemetry (nivel Medio+)
│   └── schemas/             # Modelos Pydantic compartidos
├── ml/
│   ├── train_model.py
│   ├── diagnostico.py
│   ├── build_sisfall_dataset.py
│   ├── model.pkl            # Modelo activo (migrar a artifacts/ + registry/)
│   ├── model_ablation.pkl
│   ├── registry/            # Metadata de versiones de modelo (nivel Experto)
│   └── artifacts/           # Artefactos versionados
├── notebooks/
│   └── eda_sisfall.py
├── data/
│   ├── raw/
│   │   ├── sisfall/         # .txt crudos (gitignored)
│   │   └── kaggle/          # Descarga Kaggle (gitignored)
│   ├── processed/           # CSVs tabulares + eda_output/
│   └── feedback/            # Datos desde app (gitignored)
├── tests/
│   └── test_health.py
├── Dockerfile
├── requirements.txt
└── README.md
```

> Ejecutar scripts desde la **raíz de `Backend/`**.

## Datasets

Ver [data/README.md](data/README.md). **Política:** crudos y procesados en git.

| ID | Ubicación | Estado |
|---|---|---|
| DS-01 SisFall crudo | `data/raw/sisfall/` | Pendiente subir |
| DS-01b SisFall procesado | `data/processed/sisfall_dataset.csv` | En repo |
| DS-02 Kaggle | `data/raw/kaggle/` | Pendiente subir |
| DS-03 Sintético | `data/processed/fall_detection_dataset.csv` | Deprecado |

```bash
# Regenerar DS-01 desde crudos
python ml/build_sisfall_dataset.py --root data/raw/sisfall --out data/processed/sisfall_dataset.csv
```

## Pipeline ML

```bash
python notebooks/eda_sisfall.py
python ml/train_model.py
python ml/diagnostico.py
```

## API

```bash
uvicorn api.main:app --reload --port 8000
```

## Variables de entorno

Ver `infra/.env.example`. Producción (Render): `SUPABASE_URL`, `SUPABASE_KEY`, `MODEL_PATH`.

## Tests

```bash
pytest tests/ -v
```
