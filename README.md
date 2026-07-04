# Fall-Sentinel (Proyecto5 — Grupo 1)

Sistema de detección de caídas mediante Machine Learning: app móvil Flutter + API FastAPI.

Proyecto del **Bootcamp de Inteligencia Artificial de Factoría F5 Madrid** (Grupo 1).

---

## Estructura del repositorio

```
├── Frontend/     # App Flutter (Fall Detector Tester)
├── Backend/      # FastAPI, ML, EDA y datasets (SisFall)
├── docs/         # Daily standups del equipo
│   └── daily/
├── .specify/     # Orquestación IA y especificaciones SDD
└── .github/      # CI/CD (Android release + Firebase)
```

---

## Inicio rápido

### Frontend (Flutter)

```bash
cd Frontend
flutter pub get
flutter run
```

### Backend (FastAPI)

```bash
cd Backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```

API desplegada en: `https://proyecto5-grupo1.onrender.com`

---

## Backend — ML y datos

| Recurso | Ubicación |
|---|---|
| API FastAPI | `Backend/main.py` |
| Dataset SisFall procesado | `Backend/data/sisfall_dataset.csv` |
| Dataset sintético (legacy) | `Backend/data/fall_detection_dataset.csv` |
| EDA (script Python) | `Backend/eda_sisfall.py` |
| Entrenamiento | `Backend/train_model.py` |
| Modelos entrenados | `Backend/model.pkl`, `Backend/model_ablation.pkl` |
| Salida EDA | `Backend/eda_output/` |

> **Nota:** No hay notebooks `.ipynb` de Kaggle. El equipo trabaja con el dataset **SisFall** (archivos `.txt` crudos → CSV tabular) mediante scripts Python.

---

## Documentación

- [Daily standups](docs/daily/)
- Especificaciones SDD: `.specify/specs/factoria/` (`1_intent.md` → `4_task.md`)

La documentación de gestión del proyecto se mantiene en **Confluence** y **Jira**.

---

## Equipo

Grupo 1 — Gabriela, Jose, Josue, Arnaldo (Factoría F5 Madrid)
