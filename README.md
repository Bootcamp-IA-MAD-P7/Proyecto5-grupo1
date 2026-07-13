# SentiLife (Proyecto5 — Grupo 1)

Plataforma de monitorización y mejora de la calidad de vida asistida por
Inteligencia Artificial. Su núcleo MVP detecta caídas en tiempo real a partir de
telemetría IMU y avisa a la persona cuidadora.

Proyecto del **Bootcamp de Inteligencia Artificial de Factoría F5 Madrid** (Grupo 1).  
Objetivo: alcanzar el **nivel Experto** según `.specify/memory/constitucion_factoria.md`.

**Stack actual:** Flutter · **Spring Boot 3 (Java 21)** · FastAPI (inferencia ML) · PostgreSQL · RabbitMQ · Prometheus · Grafana

**Arquitectura:** Flutter habla solo con el **backend Java** (API pública). El servicio **FastAPI/inference** es interno — Java lo invoca para clasificar ventanas IMU.

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
| `make up` | Levanta stack completo (Java + inference + DB + RabbitMQ + observabilidad) |
| `make verify` | Fail-fast: health checks de todos los contenedores + Java + inference |
| `make logs` | Logs de `backend`, `api` y `db` |
| `make down` | Para contenedores |
| `make reset-db` | Borra volumen Postgres (`down -v`) |
| `make test` | Corre los 3 suites (Java + Python + Flutter), igual que CI |
| `make test-java` / `test-python` / `test-flutter` | Suite individual |
| `make flutter-local` | Flutter → Java API local (`:8080`) |
| `make flutter-phone` | Igual + usa `API_HOST` y `DEVICE` del `.env` |
| `make flutter-qa` | Flutter → Java API en EC2 (`:8005`) |
| `make smoke-telemetry` | **T1.INT / SL-25** — smoke E2E telemetría real (requiere `make up`) |
| `make smoke-mvp` | **T2.INT / SL-43** — MVP E2E: caída → alerta → push → confirmar → export IT |
| Clone limpio | **T0.INT / SL-15** — ver [§Clone limpio](#0-clone-limpio-t0int--sl-15) |

### Variables en `.env`

| Variable | Valor local | Uso |
|---|---|---|
| `JAVA_PORT` | `8080` | Backend Java (API pública) |
| `PORT` | `8000` | Inference FastAPI (interno) |
| `POSTGRES_HOST_PORT` | `5433` | Postgres host (evita conflicto con postgres local) |
| `JWT_SECRET` | ver `.env.example` | Firma JWT del backend Java |
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

Emulador: `cd frontend && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080`

### Smoke telemetría real (T1.INT / SL-25)

Verifica el pipeline completo **sin móvil**: CAREGIVER registra persona → MONITORED empareja → consentimiento → `POST /telemetry/windows` → Java → FastAPI `/predict` (modelo XGBoost real).

```bash
make up
make smoke-telemetry
```

**Latencia medida 2026-07-13** (stack local, `docker compose`):

| Métrica | Valor |
|---|---|
| E2E `POST /telemetry/windows` (ventana ADL) | **197 ms** |
| E2E `POST /telemetry/windows` (caída simulada) | **61 ms** |
| FastAPI `/predict` (inferencia ML) | **16 ms** |
| Modelo servido | `baseline-v1` (XGBoost) |

En móvil físico: `make flutter-phone` → login MONITORED → pairing `SL-XXXXXX` → consentimiento → iniciar monitorización; la pantalla MONITORED muestra `fallDetected`, `confidence` y `modelVersion` de la última evaluación.

### MVP end-to-end (T2.INT / SL-43)

Flujo completo vía API: CAREGIVER registra persona → MONITORED empareja + consentimiento → caída simulada → alerta + push FCM → confirmar con comentario → IT_ADMIN export con muestra `TRUE_FALL`.

```bash
make up
make smoke-mvp
```

**Latencia medida 2026-07-13:**

| Métrica | Valor |
|---|---|
| Alerta visible (`GET /alerts`) | **291 ms** |
| Push pipeline (RabbitMQ → FCM) | **325 ms** |
| Export IT con `TRUE_FALL` | ✅ |

En móvil: login CAREGIVER en un dispositivo + MONITORED en otro (o emulador); tras caída simulada el push debe llegar en < 5 s (`make flutter-phone` en ambos).

### URLs locales (desarrollo)

| Servicio | URL | Acceso |
|---|---|---|
| **Java API** (pública) | http://localhost:8080/actuator/health | Flutter + clientes |
| Java REST | http://localhost:8080/api/v1/... | Auth, telemetría, alertas |
| Inference ML (interno) | http://localhost:8000/health | Solo Java / dev |
| Inference Swagger | http://localhost:8000/docs | Solo desarrollo |
| Grafana | http://localhost:3000 | Dashboards (`admin`/`admin`) |
| Prometheus | http://localhost:9090 | Métricas |
| Postgres | `localhost:5433` | Debug (DBeaver/psql) |
| RabbitMQ UI | http://localhost:15673 | Management (`guest`/`guest`) |
| Flutter móvil | http://\<IP-LAN\>:8080 | Misma WiFi que el PC |

### URLs QA / Producción (EC2 — `34.235.130.33`)

| Servicio | URL | Acceso |
|---|---|---|
| **Java API** (pública) | http://34.235.130.33:8005/actuator/health | Flutter + clientes |
| Java REST | http://34.235.130.33:8005/api/v1/... | Auth, telemetría, alertas |
| Postgres (debug) | `34.235.130.33:5435` | Solo admin (DBeaver/psql) |
| Grafana | http://34.235.130.33:3006 | Dashboards (`admin`/`admin`) |
| Inference ML | interno `:8000` | No expuesto — Java lo consume |
| RabbitMQ / Prometheus | internos | No expuestos |

Flutter contra QA (sin levantar backend local):

```bash
cp .env.qa.example .env.qa
make flutter-qa
```

---

## Mapa del repositorio

```
Proyecto5-grupo1/
├── frontend/              # App Flutter (SentiLife)
├── backend/               # API Java Spring Boot 3 — puerta de entrada pública
├── inference/             # Servicio FastAPI — inferencia ML (interno)
├── contracts/             # Contrato SL-14 ventana (Flutter ↔ Java ↔ ML)
├── db/init/               # SQL init Postgres
├── backend/observability/ # Prometheus + Grafana
├── scripts/               # verify-local.sh · run-flutter-*.sh
├── docker-compose.yml     # Stack completo local
├── docker-compose.prod.yml # Deploy EC2 (CI/CD)
├── .env.example           # copiar a .env (local)
├── .env.qa.example        # copiar a .env.qa (Flutter → EC2)
├── Makefile
├── docs/daily/
├── .specify/
└── .github/workflows/     # ci.yml · android.yml
```

Documentación por módulo: [frontend/README.md](frontend/README.md) · [backend/README.md](backend/README.md) · [inference/README.md](inference/README.md) · [db/README.md](db/README.md)

---

## Frontend — estructura detallada

App **SentiLife** (`com.sentilife.app`). Monitoriza IMU + contexto y consulta la API de predicción.

```
frontend/
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

| Modo API | Configuración | URL base |
|---|---|---|
| QA (EC2) | `make flutter-qa` + `.env.qa` | http://34.235.130.33:8005 |
| Local — emulador | `make flutter-local` | http://10.0.2.2:8080 |
| Local — móvil físico | `make flutter-phone` | http://\<IP-LAN\>:8080 |
| Offline | `_useMock = true` en servicios | Sin backend |

```bash
cd frontend && flutter pub get && flutter run
```

**QA:** http://34.235.130.33:8005 (Java API)  
**Local:** http://\<IP-LAN\>:8080 vía `make up`

---

## Backend Java — API pública (`backend/`)

Spring Boot 3 + Java 21. **Única puerta de entrada** para Flutter y clientes externos: autenticación JWT, usuarios, telemetría, alertas, notificaciones FCM y administración.

```
backend/
├── src/main/java/com/sentilife/
│   ├── auth/           # JWT, login, registro
│   ├── telemetry/      # Ingesta ventanas → llama inference
│   ├── alerts/         # Alertas + feedback
│   ├── notifications/  # Push FCM
│   ├── admin/          # Historial, export, retrain
│   └── ota/            # OTA Android
├── src/main/resources/db/migration/  # Flyway
├── observability/      # Prometheus + Grafana
├── Dockerfile
└── pom.xml
```

| Entorno | URL health | Puerto |
|---|---|---|
| Local | http://localhost:8080/actuator/health | 8080 |
| EC2 QA | http://34.235.130.33:8005/actuator/health | 8005 |

```bash
make test-java          # mvn test (H2 en memoria)
cd backend && mvn spring-boot:run   # sin Docker
```

Detalle: [backend/README.md](backend/README.md)

---

## Inference — servicio ML interno (`inference/`)

FastAPI aislado. **No lo consume Flutter directamente** — el backend Java llama a `INFERENCE_URL` (red Docker interna) para clasificar ventanas IMU.

```
inference/
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
cd inference
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn api.main:app --reload --port 8000
pytest tests/ -v
```

> Ejecutar scripts ML desde la **raíz de `inference/`**.

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

Detalle completo: [inference/data/README.md](inference/data/README.md)

---

## CI/CD

Flujo: push/PR a **cualquier rama** (tests) → merge a **`main`** (deploy completo).

| Workflow | Cuándo | Qué hace |
|---|---|---|
| `ci.yml` | push a **toda rama** + PR a `main`/`dev` | ☕ mvn test + 🐍 pytest + 🦋 flutter test |
| `ci.yml` | push a `main` (tras tests OK) | build Docker Hub + deploy EC2 |
| `android.yml` | tras `ci.yml` OK en `main` | APK firmado → GitHub Release → Firebase |

**Regla de bloqueo:** si cualquier test suite falla (Java, Python o Flutter) el pipeline para. No se construyen imágenes, no se despliega.

**Orden en push a `main`:** `ci.yml` (tests → build → deploy EC2); al terminar con éxito se lanza `android.yml` (APK, Firebase). Detalle: `.specify/specs/factoria/3_plan.md` §5.

`EC2_HOST` debe estar como secret a **nivel repositorio**.

### Puertos QA (EC2 — `34.235.130.33`)

| Servicio | Puerto host | URL | Expuesto |
|---|---|---|---|
| **Java API** | **8005** | http://34.235.130.33:8005 | ✅ Sí — Flutter + clientes |
| Postgres (debug) | **5435** | `34.235.130.33:5435` | ✅ Sí — solo admin |
| Grafana | **3006** | http://34.235.130.33:3006 | ✅ Sí — dashboards |
| Inference FastAPI | 8000 | — | ❌ Interno Docker |
| RabbitMQ | 5672 | — | ❌ Interno Docker |
| Prometheus | 9090 | — | ❌ Interno Docker |

Abrir en Security Group: **TCP 8005** (Java API), **TCP 5435** (Postgres debug), **TCP 3006** (Grafana).

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
| Esencial | ✅ Cerrado | T0.INT + T1.INT verificados |
| Medio | ✅ Cerrado | T2.INT (`make smoke-mvp`) |
| Avanzado | ~50% | EC2 QA, tests ampliados, GDPR, i18n |
| Experto | ~40% | CNN/LSTM, MLOps UI, drift |

> El SDD formal ya está definido y enlazado en la sección
> [Documentación](#documentación).

---

## Deuda técnica

- ~~Mocks Flutter~~ — todos los servicios en backend real (`AppConfig.useMock=false`) ✅
- **No regenerar** `processed/` hasta SDD
- MobiAct pendiente de respuesta BMI
- Endpoint OTA `/app/register-version` pendiente en Java (CI android.yml)

---

## Inicio rápido — local

### 0. Clone limpio (T0.INT / SL-15)

Flujo verificado en máquina nueva (13/07/2026):

```bash
git clone <url-repo> Proyecto5-grupo1 && cd Proyecto5-grupo1
cp .env.example .env          # make up también lo crea vía target env
make up                       # build + levanta 6 servicios + verify automático
make verify                   # re-comprobar health checks
make flutter-local            # emulador Android → Java API en 10.0.2.2:8080
```

**Prerrequisitos:** Docker Compose v2 · Flutter SDK (3.x) · Android SDK (`ANDROID_HOME`, `JAVA_HOME` para Java 17).

| Paso | Resultado esperado |
|---|---|
| `make up` | 6 contenedores `healthy`: db, rabbitmq, backend, api, prometheus, grafana |
| `make verify` | HTTP OK en `:8000/health` (inference) y `:8080/actuator/health` (Java) |
| `make flutter-local` | App SentiLife en emulador; login contra backend real |

**Fricciones conocidas (no bloquean el MVP local):**

| Fricción | Impacto | Mitigación |
|---|---|---|
| Primera build Docker ~3–5 min | Imagen inference incluye datos ML (~790 MB context) | Normal en clone nuevo; builds posteriores usan caché |
| Primera build Flutter ~8 min | Gradle descarga NDK/SDK Android | Solo la primera vez en la máquina |
| Sin `secrets/` Firebase | Warnings en `make up`; push FCM deshabilitado | Opcional para login/telemetría/alertas vía polling. Ver [docs/firebase-setup.md](docs/firebase-setup.md) |
| Puertos 5433 / 5673 / 15673 | Evitan conflicto con Postgres/RabbitMQ locales | Cambiar en `.env` si ya están ocupados |
| Emulador Android requerido | `make flutter-local` usa `10.0.2.2:8080` | Crear AVD en Android Studio o `make flutter-phone` con móvil físico |
| `flutter` no en PATH | `make flutter-local` falla | Añadir `export PATH="$HOME/flutter/bin:$PATH"` al shell |

Push FCM y smoke MVP (`make smoke-mvp`) requieren Firebase configurado — ver [docs/firebase-setup.md](docs/firebase-setup.md).

### 1. Stack completo (Docker)

```bash
cp .env.example .env    # primera vez
make up                 # Java + inference + DB + RabbitMQ + Grafana + Prometheus
make verify             # re-comprobar todos los health checks
make logs               # si algo falla
```

Requisitos: Docker Compose v2.

| Servicio | URL local |
|---|---|
| Java API | http://localhost:8080/actuator/health |
| Inference | http://localhost:8000/health |
| Grafana | http://localhost:3000 |

### 2. Flutter contra la infraestructura local

```bash
# Emulador Android (Java API en 10.0.2.2:8080)
make flutter-local

# Móvil físico en la misma WiFi
make flutter-phone      # usa API_HOST y DEVICE del .env
```

`make flutter-local` comprueba antes que el stack esté sano. Flutter apunta al **backend Java** (`:8080`), no al inference.

### 3. Tests (igual que CI)

```bash
make test               # Java + Python + Flutter
make test-java          # solo mvn test
make test-python        # solo pytest
make test-flutter       # solo flutter test
```

### 4. Inference sin Docker (opcional)

```bash
cd inference
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn api.main:app --reload --host 0.0.0.0 --port 8000
```

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
| Contrato SL-14 de ventana | [window_contract.md](contracts/window_contract.md) |
| Constitución Factoría | [constitucion_factoria.md](.specify/memory/constitucion_factoria.md) |

---

## Mapa de datasets y verificaciones

**Política:** los crudos van en GitHub — fuente de verdad del equipo. Tras `git clone`, ejecutar las verificaciones antes de entrenar.

| ID | Fuente | Ruta crudo | Ruta procesado | Estado | Esperado |
|---|---|---|---|---|---|
| **DS-01** | SisFall | `inference/data/raw/sisfall/` | `inference/data/processed/sisfall/` | ✅ En repo | 4.396 `.txt` · 38 sujetos · CSV 4.506 filas |
| **DS-02** | MobiAct v2.0 | `inference/data/raw/mobiact/mobiact_v2.0/` | `inference/data/processed/mobiact/mobiact_v2.0/` | ⏳ Pendiente BMI | 3 `.txt`/ensayo (acc, gyro, orientación) |
| **DS-02b** | MobiFall v2.0 | `inference/data/raw/mobiact/mobifall_v2.0/` | `inference/data/processed/mobiact/mobifall_v2.0/` | ⏳ Pendiente BMI | >3.200 ensayos · 66 sujetos |
| ~~DS-X~~ | Kaggle zara2099 | `inference/data/raw/kaggle/` | — | ❌ Baja | Solo `DEPRECATED.md` |
| **DS-C** | Combinado | — | `inference/data/processed/combined/` | 🔒 Futuro | Tras SDD + EDA DS-01/DS-02 |

### Script de verificación (copiar tras clone)

```bash
cd inference/data/raw/sisfall
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

Detalle académico completo: [inference/data/README.md](inference/data/README.md)

---

## Equipo

Grupo 1 — Gabriela, Jose, Josue, Arnaldo (Factoría F5 Madrid)
