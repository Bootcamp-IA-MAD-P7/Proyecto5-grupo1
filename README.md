# Fall-Sentinel (Proyecto5 — Grupo 1)

Sistema de detección de caídas mediante Machine Learning: app móvil Flutter + API FastAPI.

Proyecto del **Bootcamp de Inteligencia Artificial de Factoría F5 Madrid** (Grupo 1).  
Objetivo de entrega: alcanzar el **nivel Experto** según `.specify/memory/constitucion_factoria.md`.

---

## Estructura del repositorio

```
Proyecto5-grupo1/
├── Frontend/                    # App Flutter
├── Backend/
│   ├── api/                     # FastAPI + inference + routes + schemas
│   ├── ml/                      # Entrenamiento, registry, artifacts
│   ├── notebooks/               # EDA y experimentos
│   ├── data/
│   │   ├── raw/sisfall/         # SisFall .txt (gitignored)
│   │   ├── raw/kaggle/          # Kaggle (gitignored)
│   │   ├── processed/           # CSVs y EDA
│   │   └── feedback/            # Datos desde app (gitignored)
│   └── tests/
├── infra/                       # docker-compose + .env.example
├── docs/daily/
├── .specify/                    # SDD formal (1_intent → 4_task) — próximo paso
├── .github/workflows/           # android.yml + backend-ci.yml
└── render.yaml                  # Deploy API en Render
```

Documentación por módulo: [Frontend/README.md](Frontend/README.md) · [Backend/README.md](Backend/README.md) · [infra/README.md](infra/README.md)

---

## Estrategia de datasets

**Política:** todos los datasets (crudos y procesados) van **en el repositorio**. El equipo trabaja con `git clone` — sin scripts ni descargas manuales.

| ID | Fuente | Ubicación | Estado |
|---|---|---|---|
| **DS-01** | SisFall crudo | `Backend/data/raw/sisfall/` | Pendiente — subir `.txt` originales |
| **DS-01b** | SisFall procesado | `Backend/data/processed/sisfall_dataset.csv` | En repo |
| **DS-02** | Kaggle Real-Time Patient Fall Detection | `Backend/data/raw/kaggle/` | Pendiente — subir CSV originales |
| **DS-03** | Sintético legacy | `Backend/data/processed/fall_detection_dataset.csv` | En repo (deprecado) |

Detalle: [Backend/data/README.md](Backend/data/README.md)

---

## Roadmap Factoría F5 (estado actual)

Referencia: `.specify/memory/constitucion_factoria.md`

| Nivel | Estado | Pendiente clave |
|---|---|---|
| Esencial | ~70% | Integrar `model.pkl` en API (`api/inference/`) |
| Medio | ~50% | Optuna, endpoint `/feedback`, ingesta en `data/feedback/` |
| Avanzado | ~40% | Tests ampliados, telemetría en DB, CI backend estable |
| Experto | ~5% | LSTM/CNN, MLOps: drift, A/B testing, auto-reemplazo de modelos |

> El SDD formal (`.specify/specs/factoria/1_intent.md` → `4_task.md`) se redactará **cuando esta estructura e infra estén cerradas**.

---

## Deuda técnica conocida

- La API en producción usa umbrales (`classify()`), no el modelo entrenado en `ml/model.pkl`
- **DS-02 Kaggle** y **DS-01 SisFall crudo** pendientes de subir a `data/raw/` (ver `Backend/data/README.md`)
- Sin endpoints `/feedback` ni persistencia de predicciones en DB
- `api/inference/`, `api/routes/`, `ml/registry/` creados como esqueleto — sin lógica aún

---

## Inicio rápido

### Frontend

```bash
cd Frontend && flutter pub get && flutter run
```

### Backend (local)

```bash
cd Backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn api.main:app --reload
```

### Backend + DB (Docker)

```bash
cp infra/.env.example infra/.env
docker compose -f infra/docker-compose.yml up --build
```

API producción: `https://proyecto5-grupo1.onrender.com`

---

## Documentación

| Recurso | Ubicación |
|---|---|
| Daily standups | [docs/daily/](docs/daily/) |
| SDD formal (próximo) | `.specify/specs/factoria/` (`1_intent.md` → `4_task.md`) |
| Borradores temporales | `.specify/specs/factoria/SDD.md`, `AGENTS.md` (eliminar tras migrar) |
| Gestión proyecto | Confluence + Jira |

---

## Equipo

Grupo 1 — Gabriela, Jose, Josue, Arnaldo (Factoría F5 Madrid)
