# SentiLife (Proyecto5 — Grupo 1)

Plataforma de monitorización y mejora de la calidad de vida asistida por
Inteligencia Artificial. Su núcleo MVP detecta caídas en tiempo real a partir de
telemetría IMU y avisa a la persona cuidadora.

Proyecto del **Bootcamp de Inteligencia Artificial de Factoría F5 Madrid** (Grupo 1).  
Objetivo: alcanzar el **nivel Experto** según `.specify/memory/constitucion_factoria.md`.

**Stack disponible actualmente:** Flutter · FastAPI · PostgreSQL (Docker) · scikit-learn / XGBoost

**Arquitectura objetivo:** Flutter · Spring Boot · FastAPI · PostgreSQL · RabbitMQ ·
Prometheus · Grafana. La telemetría se persiste en PostgreSQL durante el sprint;
InfluxDB queda como evolución post-entrega según ADR-03.

---

## Arquitectura

```text
┌──────────────────────── Flutter (SentiLife) ────────────────────────┐
│ MONITORED · CAREGIVER · IT_ADMIN                                   │
└──────────────────────────────┬─────────────────────────────────────┘
                               │ HTTPS + JWT
                    ┌──────────▼──────────┐
                    │ Backend Spring Boot │
                    │ negocio y seguridad │
                    └───┬───────────┬─────┘
                        │           │ HTTP síncrono
              ┌─────────▼───┐   ┌───▼────────────────┐
              │ PostgreSQL  │   │ FastAPI            │
              │ negocio +   │   │ inferencia ML      │
              │ telemetría  │   │ modelo versionado  │
              └─────────────┘   └────────────────────┘
                        │
                  RabbitMQ
              alertas y notificaciones

       Prometheus recopila métricas · Grafana las visualiza
```

- **Flutter** captura sensores, construye ventanas y ofrece las interfaces para
  los tres perfiles.
- **Spring Boot** es la única puerta de entrada: autentica, aplica roles y
  consentimiento, persiste datos y coordina alertas.
- **FastAPI** queda aislado como servicio interno de inferencia; Flutter no lo
  invoca directamente en producción.
- **RabbitMQ** desacopla alertas y notificaciones. La predicción usa HTTP
  síncrono para proteger el objetivo de latencia.
- **Prometheus y Grafana** proporcionan métricas y observabilidad del pipeline.

El diseño completo y sus decisiones están en
[3_plan.md](.specify/specs/factoria/3_plan.md).

---

## Comandos del equipo (desde la raíz del repo)

| Comando | Qué hace |
|---|---|
| `cp .env.example .env` | Primera vez — crea variables locales |
| `make up` | Levanta `fallsentinel-api` + `fallsentinel-db`, verifica endpoints |
| `make verify` | Fail-fast: `/health`, `/predict`, Postgres |
| `make logs` | Logs de API y DB |
| `make down` | Para contenedores |
| `make reset-db` | Borra volumen Postgres (`down -v`) — tras cambiar password |
| `make flutter-local API_HOST=192.168.x.x` | Flutter → API en tu IP LAN |
| `make flutter-phone` | Igual + usa `DEVICE` del `.env` |
| `make flutter-qa` | Flutter → API QA en EC2 (`cp .env.qa.example .env.qa`) |
| `make test-backend` | pytest sin Docker |

### Variables en `.env`

| Variable | Valor local | Uso |
|---|---|---|
| `POSTGRES_PASSWORD` | ver `.env.example` | Credencial DB (solo local/QA) |
| `DATABASE_URL` | ver `.env.example` | API → Postgres |
| `API_HOST` | IP LAN de tu PC | Flutter en móvil físico |
| `DEVICE` | ej. `OJLNRO8PNFLNNBFA` | ID adb / `flutter devices` |

### Flutter en móvil (misma WiFi + USB debug)

```bash
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

make up
hostname -I | awk '{print $1}'    # copiar IP → API_HOST en .env
adb devices                       # copiar id → DEVICE en .env
make flutter-phone
```

Emulador: `cd Frontend && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`

### URLs locales

| URL | Descripción |
|---|---|
| http://localhost:8000/health | Healthcheck |
| http://localhost:8000/docs | Swagger |
| http://localhost:8000/predict | Predicción (umbrales) |
| http://\<IP-LAN\>:8000/predict | Desde el móvil |

### ¿Qué lee la base de datos hoy?

Solo **versiones OTA** (`app_versions`): `GET/POST /app/*`.  
`/predict` no usa DB.

Detalle SQL: [db/README.md](db/README.md)

### URLs QA (EC2)

| URL | Descripción |
|---|---|
| http://34.235.130.33:8005/health | Healthcheck |
| http://34.235.130.33:8005/docs | Swagger |
| http://34.235.130.33:8005/predict | Predicción |

Flutter contra QA (sin levantar backend local):

```bash
cp .env.qa.example .env.qa
make flutter-qa
```

---

## Mapa del repositorio

```
Proyecto5-grupo1/
├── Frontend/              # App Flutter
├── Backend/               # API + ML + data/
├── db/init/               # SQL init Postgres (app_versions)
├── scripts/               # verify-local.sh · run-flutter-local.sh
├── docker-compose.yml     # fallsentinel-api + fallsentinel-db (local)
├── docker-compose.prod.yml # API + DB en EC2 (CI/CD)
├── .env.example           # copiar a .env (local)
├── .env.qa.example        # copiar a .env.qa (Flutter → EC2)
├── Makefile               # make up · verify · flutter-phone
├── docs/daily/
├── .specify/
└── .github/workflows/
```

Documentación por módulo: [Frontend/README.md](Frontend/README.md) · [Backend/README.md](Backend/README.md) · [db/README.md](db/README.md) · [Backend/data/README.md](Backend/data/README.md)

---

## Frontend — estructura detallada

App **SentiLife** (`com.sentilife.app`). Monitoriza IMU + contexto y consulta la API de predicción.

```
Frontend/
├── lib/                              # Código Dart (multiplataforma)
│   ├── main.dart                     # Entrada, tema Material, chequeo OTA al arrancar
│   ├── config/
│   │   └── app_config.dart         # API_BASE_URL vía --dart-define
│   ├── models/
│   │   └── prediction_result.dart    # Resultado + snapshot de sensores
│   ├── screens/
│   │   ├── home_screen.dart          # Monitor en tiempo real, stream de sensores
│   │   └── result_screen.dart        # Alerta visual si caída detectada
│   ├── services/
│   │   ├── api_service.dart          # POST /predict (API local o AWS)
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
| QA (EC2) | `make flutter-qa` + `.env.qa` | Debug frontend sin Docker local |
| Local | `make flutter-local API_HOST=192.168.x.x` | Desarrollo en LAN |
| Offline | `_useMock = true` | Desarrollo sin backend |

```bash
cd Frontend && flutter pub get && flutter run
```

**QA:** http://34.235.130.33:8005  
**Local:** API en `http://<IP-LAN>:8000` vía `make up`

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
├── Dockerfile                        # Imagen Docker (local + EC2)
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

Flujo: push/PR a **`dev`** (solo tests) → merge a **`main`** (deploy completo).

| Workflow | Rama | Qué hace |
|---|---|---|
| `backend-ci.yml` | push/PR `dev` | pytest + data layout + import check |
| `backend-ci.yml` | push `main` | tests + Docker Hub + deploy EC2 (DB + API) |
| `android.yml` | tras `backend-ci` OK en `main` | analyze → APK → Release → Firebase → OTA |

**Orden en push a `main`:** primero `backend-ci` (DB + API); al terminar con éxito se lanza `android.yml` (APK, Firebase, OTA). Detalle: `.specify/specs/factoria/3_plan.md` §5.

`EC2_HOST` debe estar como secret a **nivel repositorio**.

### Puertos QA (EC2)

| Servicio | Puerto host |
|---|---|
| API | **8005** |
| Postgres (debug) | **5435** |
| Frontend (reservado) | **3006** |

Abrir en Security Group: **TCP 8005** (API) y **TCP 5435** (Postgres debug, opcional).

### Secrets GitHub (environment `production`)

| Secret | Nota |
|---|---|
| `DOCKER_USERNAME` | Usuario Docker Hub |
| `DOCKER_PASSWORD` | Token Docker Hub |
| `EC2_HOST` | `34.235.130.33` |
| `EC2_USER` | `ubuntu` o `ec2-user` |
| `EC2_SSH_KEY` | Clave PEM privada |

Credenciales Postgres: mismas que `.env.example` (no commitear `.env` ni `.env.qa`).

---

## Roadmap Factoría F5

| Nivel | Estado | Pendiente clave |
|---|---|---|
| Esencial | ~70% | Integrar `model.pkl` en `api/inference/` |
| Medio | ~50% | Optuna, `/feedback`, ingesta `data/feedback/` |
| Avanzado | ~40% | Tests ampliados, telemetría DB, CI estable |
| Experto | ~5% | LSTM/CNN, MLOps, drift, A/B testing |

> El SDD formal ya está definido y enlazado en la sección
> [Documentación](#documentación).

---

## Deuda técnica

- API usa umbrales (`classify()`), no `model.pkl`
- **No regenerar** `processed/` hasta SDD
- MobiAct pendiente de respuesta BMI
- Mock de desarrollo **solo** en Flutter (`api_service.dart`)

---

## Inicio rápido — Sprint día 0 (local a prueba de balas)

### 1. Backend + PostgreSQL (Docker)

```bash
make up          # cp .env + docker compose + verify automático
make verify      # re-comprobar /health, /predict, Postgres
make logs        # si algo falla
```

Requisitos: Docker Compose v2. La API queda en **http://localhost:8000** (Swagger: `/docs`).

### 2. Flutter en tu móvil (misma WiFi)

```bash
# Sustituye por la IP de tu PC en la red local
make flutter-local API_HOST=192.168.1.100
```

El build **debug** permite HTTP a la API local. Emulador Android:

```bash
cd Frontend && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

### 3. Backend sin Docker (opcional)

```bash
cd Backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn api.main:app --reload --host 0.0.0.0 --port 8000
```

> Sin Postgres local, `/app/latest-version` devolverá 503 — usa `make up` para stack completo.

Detalle DB: [db/README.md](db/README.md)

---

## Documentación

| Recurso | Ubicación |
|---|---|
| Daily standups | [docs/daily/](docs/daily/) |
| 1. Intención: visión y alcance | [1_intent.md](.specify/specs/factoria/1_intent.md) |
| 2. Especificación: requisitos y contratos | [2_spec.md](.specify/specs/factoria/2_spec.md) |
| 3. Plan: arquitectura, ADR y CI/CD | [3_plan.md](.specify/specs/factoria/3_plan.md) |
| 4. Tareas: backlog ejecutable | [4_task.md](.specify/specs/factoria/4_task.md) |
| Roadmap y tablero de estado | [5_roadmap.md](.specify/specs/factoria/5_roadmap.md) |
| Constitución Factoría | [constitucion_factoria.md](.specify/memory/constitucion_factoria.md) |

---

## Mapa de datasets y verificaciones

**Política:** los crudos van en GitHub — fuente de verdad del equipo. Tras `git clone`, ejecutar las verificaciones antes de entrenar.

| ID | Fuente | Ruta crudo | Ruta procesado | Estado | Esperado |
|---|---|---|---|---|---|
| **DS-01** | SisFall | `Backend/data/raw/sisfall/` | `Backend/data/processed/sisfall/` | ✅ En repo | 4.396 `.txt` · 38 sujetos · CSV 4.506 filas |
| **DS-02** | MobiAct v2.0 | `Backend/data/raw/mobiact/mobiact_v2.0/` | `Backend/data/processed/mobiact/mobiact_v2.0/` | ⏳ Pendiente BMI | 3 `.txt`/ensayo (acc, gyro, orientación) |
| **DS-02b** | MobiFall v2.0 | `Backend/data/raw/mobiact/mobifall_v2.0/` | `Backend/data/processed/mobiact/mobifall_v2.0/` | ⏳ Pendiente BMI | >3.200 ensayos · 66 sujetos |
| ~~DS-X~~ | Kaggle zara2099 | `Backend/data/raw/kaggle/` | — | ❌ Baja | Solo `DEPRECATED.md` |
| **DS-C** | Combinado | — | `Backend/data/processed/combined/` | 🔒 Futuro | Tras SDD + EDA DS-01/DS-02 |

### Script de verificación (copiar tras clone)

```bash
cd Backend/data/raw/sisfall
echo "SisFall sujetos: $(ls -d SA* SE* 2>/dev/null | wc -l) (esperado: 38)"
echo "SisFall ensayos: $(find . -name '*.txt' ! -iname 'readme.txt' | wc -l) (esperado: 4396)"
test -f Readme.txt && echo "Readme.txt: OK" || echo "Readme.txt: FALTA"

cd ../../processed/sisfall
test -f sisfall_dataset.csv && echo "processed CSV: OK ($(wc -l < sisfall_dataset.csv) lineas)" || echo "processed CSV: FALTA"

cd ../mobiact
MOBI=$(find ../../raw/mobiact -name '*.txt' 2>/dev/null | wc -l)
if [ "$MOBI" -eq 0 ]; then echo "MobiAct: pendiente (email bmi@hmu.gr)"; else echo "MobiAct archivos: $MOBI"; fi
```

### Plan B si MobiAct no responde a tiempo

| Alternativa | Contacto / URL | Acción |
|---|---|---|
| **Solo SisFall (DS-01)** | Ya en repo | Suficiente para Factoría F5; documentar limitación de sesgo en SDD |
| **UniMiB SHAR** | Univ. Milano-Bicocca | Reserva académica — solicitar igual que MobiAct |
| **FARSEEING** | Proyecto EU AAL | Caídas reales mayores — acceso bajo solicitud, muestras públicas limitadas |

Detalle académico completo: [Backend/data/README.md](Backend/data/README.md)

---

## Equipo

Grupo 1 — Gabriela, Jose, Josue, Arnaldo (Factoría F5 Madrid)
