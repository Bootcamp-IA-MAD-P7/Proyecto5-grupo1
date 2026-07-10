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
│   ├── build_sisfall_window_features.py
│   ├── model.pkl            # Modelo activo (migrar a artifacts/ + registry/)
│   ├── model_ablation.pkl
│   ├── registry/            # Metadata de versiones de modelo (nivel Experto)
│   └── artifacts/           # Artefactos versionados
├── notebooks/
│   └── eda_sisfall.py
├── data/
│   ├── raw/
│   │   ├── sisfall/         # DS-01 (.txt crudos)
│   │   └── mobiact/         # DS-02 candidato
│   ├── processed/           # sisfall/, mobiact/, combined/
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
| DS-01 SisFall crudo | `data/raw/sisfall/` | Descargado |
| DS-01b SisFall procesado | `data/processed/sisfall/` | En repo |
| DS-02 MobiAct | `data/raw/mobiact/` | Candidato — pendiente |
| ~~Kaggle~~ | — | Dado de baja (constitución §6) |

```bash
# Regenerar DS-01 desde crudos con ventanas SL-14 + features estadisticas
python ml/build_sisfall_window_features.py --root data/raw/sisfall --out data/processed/sisfall/sisfall_windows_features.csv.gz --manifest data/processed/sisfall/feature_manifest.json

# Legacy: una fila por ensayo completo, usado por el EDA inicial
python ml/build_sisfall_dataset.py --root data/raw/sisfall --out data/processed/sisfall/sisfall_dataset.csv
```

## Pipeline ML

```bash
python notebooks/eda_sisfall.py
python ml/build_sisfall_window_features.py
python ml/train_model.py
python ml/diagnostico.py
```

## API

```bash
uvicorn api.main:app --reload --port 8000
```

FastAPI es ahora un servicio interno de inferencia. Expone:

- `POST /predict`
- `GET /health`
- `GET /metrics`
- `GET /model/info`
- `POST /model/reload`

Los endpoints `/app/*` se conservan temporalmente por compatibilidad, marcados
como obsoletos en OpenAPI y mediante cabeceras HTTP. Su migración a Java está
pospuesta según ADR-06.

## Variables de entorno

Ver `/.env.example`. Local: `DATABASE_URL` → Postgres en Docker.

## Producción (AWS EC2 — entorno QA)

Mismas credenciales que `.env.example`.

| Recurso | URL / puerto |
|---|---|
| API | http://34.235.130.33:8005 |
| Postgres (debug) | `34.235.130.33:5435` |

Deploy automático vía `backend-ci.yml` (push a `main`). Defaults en `docker-compose.prod.yml`.

## Tests

```bash
pytest tests/ -v
```
