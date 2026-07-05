# Fall-Sentinel (Proyecto5 — Grupo 1)

Sistema de detección de caídas mediante Machine Learning: app móvil Flutter + API FastAPI.

Proyecto del **Bootcamp de Inteligencia Artificial de Factoría F5 Madrid** (Grupo 1).  
Objetivo: alcanzar el **nivel Experto** según `.specify/memory/constitucion_factoria.md`.

**Stack:** Flutter (Android) · FastAPI · scikit-learn / XGBoost · Supabase · Render · Firebase App Distribution

---

## Mapa del repositorio

```
Proyecto5-grupo1/
├── Frontend/              # App Flutter — recogida de sensores y predicción
├── Backend/               # API, ML, datasets, tests
├── infra/                 # Docker Compose local + .env.example
├── docs/daily/            # Standups del equipo
├── .specify/              # SDD formal (1_intent → 4_task) — próximo paso
├── .github/workflows/     # backend-ci.yml · android.yml
└── render.yaml            # Deploy API en Render
```

Documentación detallada por módulo: [Frontend/README.md](Frontend/README.md) · [Backend/README.md](Backend/README.md) · [infra/README.md](infra/README.md) · [Backend/data/README.md](Backend/data/README.md)

---

## Frontend — estructura detallada

App **Fall Detector Tester** (`com.jzelada.proyecto_flutter`). Monitoriza IMU + contexto y consulta la API de predicción.

```
Frontend/
├── lib/                              # Código Dart (multiplataforma)
│   ├── main.dart                     # Entrada, tema Material, chequeo OTA al arrancar
│   ├── models/
│   │   └── prediction_result.dart    # Resultado + snapshot de sensores
│   ├── screens/
│   │   ├── home_screen.dart          # Monitor en tiempo real, stream de sensores
│   │   └── result_screen.dart        # Alerta visual si caída detectada
│   ├── services/
│   │   ├── api_service.dart          # POST /predict (Render) o mock offline
│   │   └── update_service.dart       # GET /app/latest-version — OTA Android
│   └── widgets/
│       └── update_dialog.dart        # Diálogo descarga APK desde GitHub Releases
├── android/                          # Plataforma principal (release + Firebase)
│   ├── app/build.gradle.kts
│   ├── app/src/main/                 # AndroidManifest, MainActivity
│   ├── key.properties.template       # Plantilla firma release (local)
│   └── gradle/                       # Wrapper Gradle
├── ios/ · web/ · linux/ · macos/ · windows/   # Targets secundarios Flutter
├── pubspec.yaml
└── analysis_options.yaml
```

| Modo API | Configuración | Uso |
|---|---|---|
| Producción | `_useMock = false` en `api_service.dart` | Render (actual) |
| Offline | `_useMock = true` | Desarrollo sin backend |

```bash
cd Frontend && flutter pub get && flutter run
```

API producción: `https://proyecto5-grupo1.onrender.com`

---

## Backend — estructura detallada

Monorepo Python: API REST, pipeline ML y datos con **estructura espejo por fuente** (`raw/` ↔ `processed/`).

```
Backend/
├── api/                              # Capa HTTP (FastAPI)
│   ├── main.py                       # App, CORS, /predict, /health, OTA versioning
│   ├── inference/                    # [Esencial] Carga model.pkl + preprocesado
│   ├── routes/                       # [Medio] /feedback, /telemetry (esqueleto)
│   └── schemas/                      # Modelos Pydantic compartidos (esqueleto)
├── ml/                               # Entrenamiento y artefactos
│   ├── build_sisfall_dataset.py      # .txt SisFall → CSV tabular por ensayo
│   ├── train_model.py                # XGBoost + split por sujeto
│   ├── diagnostico.py                # LOSO, feature importance, sesgo por edad
│   ├── model.pkl                     # Modelo activo (no confiar hasta SDD)
│   ├── model_ablation.pkl            # Ablation sin features atajo
│   ├── registry/                     # [Experto] Metadata de versiones
│   └── artifacts/                    # [Experto] Artefactos versionados
├── notebooks/
│   └── eda_sisfall.py                # EDA pre-entrenamiento → processed/sisfall/eda_output/
├── data/
│   ├── raw/                          # Originales sin modificar
│   │   ├── sisfall/                  # DS-01 — .txt por ensayo (38 carpetas/sujeto)
│   │   │   ├── Readme.txt            # Metadatos oficiales (edad, sexo, protocolo)
│   │   │   └── SA01/ … SE15/         # F05_SA01_R04.txt, D17_SE04_R02.txt, …
│   │   ├── mobiact/                  # DS-02 candidato — solicitud a bmi@hmu.gr
│   │   │   ├── mobiact_v2.0/
│   │   │   └── mobifall_v2.0/
│   │   └── kaggle/                   # DEPRECATED — dado de baja (§6 constitución)
│   ├── processed/                    # Derivados por dataset
│   │   ├── sisfall/
│   │   │   ├── sisfall_dataset.csv   # 4.505 ensayos agregados
│   │   │   └── eda_output/           # Boxplots, sesgo, correlación
│   │   ├── mobiact/                  # Reservado (mobiact_v2.0/, mobifall_v2.0/)
│   │   └── combined/                 # Uniones documentadas (futuro)
│   ├── feedback/                     # Telemetría runtime desde app (gitignored)
│   └── README.md                     # Inventario + matriz académica de fuentes
├── tests/
│   └── test_health.py                # / y /health
├── Dockerfile                        # Imagen Render
├── requirements.txt
└── README.md
```

```bash
cd Backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn api.main:app --reload --port 8000
pytest tests/ -v
```

> Ejecutar scripts ML desde la **raíz de `Backend/`**.

---

## Estrategia de datasets

**Criterios obligatorios** (constitución §6): paper revisado por pares · consentimiento informado · citación en la comunidad. Sin soporte académico → **descartado**.

| ID | Fuente | Crudo | Procesado | Estado |
|---|---|---|---|---|
| **DS-01** | SisFall (Sucerquia et al., *Sensors* 2017) | `raw/sisfall/` | `processed/sisfall/` | **Activo** — crudo descargado |
| **DS-02** | MobiAct / MobiFall (BMI HMU) | `raw/mobiact/` | `processed/mobiact/` | **Candidato** — email a bmi@hmu.gr |
| ~~Kaggle~~ | zara2099 | — | — | **Dado de baja** — sin paper ni ética documentada |

**Stack recomendado:** SisFall (IMU cintura, benchmark) + MobiAct (smartphone, cross-dataset) → `processed/combined/` tras SDD.

**Limitación conocida:** caídas en SisFall simuladas casi solo por adultos jóvenes — ver `processed/sisfall/eda_output/analisis_sesgo.md`.

Detalle completo: [Backend/data/README.md](Backend/data/README.md)

---

## CI/CD

| Workflow | Trigger | Qué hace |
|---|---|---|
| `backend-ci.yml` | push/PR en `Backend/**` | Import check + pytest (fail-fast) |
| `android.yml` | push a `dev` | analyze → build APK → Release → Firebase |

Los pasos **no continúan** si falla uno anterior (sin `continue-on-error` en pasos críticos).

---

## Roadmap Factoría F5

| Nivel | Estado | Pendiente clave |
|---|---|---|
| Esencial | ~70% | Integrar `model.pkl` en `api/inference/` |
| Medio | ~50% | Optuna, `/feedback`, ingesta `data/feedback/` |
| Avanzado | ~40% | Tests ampliados, telemetría DB, CI estable |
| Experto | ~5% | LSTM/CNN, MLOps, drift, A/B testing |

> SDD formal (`.specify/specs/factoria/1_intent.md` → `4_task.md`) cuando datasets estén cerrados.

---

## Deuda técnica

- API usa umbrales (`classify()`), no `model.pkl`
- **No regenerar** `processed/` hasta SDD
- MobiAct pendiente de respuesta BMI
- Mock de desarrollo **solo** en Flutter (`api_service.dart`)

---

## Inicio rápido (Docker)

```bash
cp infra/.env.example infra/.env
docker compose -f infra/docker-compose.yml up --build
```

---

## Documentación

| Recurso | Ubicación |
|---|---|
| Daily standups | [docs/daily/](docs/daily/) |
| SDD formal (próximo) | `.specify/specs/factoria/` |
| Constitución Factoría | `.specify/memory/constitucion_factoria.md` |

---

## Equipo

Grupo 1 — Gabriela, Jose, Josue, Arnaldo (Factoría F5 Madrid)
