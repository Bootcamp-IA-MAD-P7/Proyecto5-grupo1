# 4. Task — SentiLife

> **Metodología SDD:** cuarto documento fundamental. Backlog ejecutable derivado de `3_plan.md`, organizado por fases y por **workstreams paralelos** (2 devs backend + 2 devs frontend, `3_plan.md` §6). Cada tarea referencia los requisitos de `2_spec.md`. Marcar con `[x]` al completar; si una tarea cambia de alcance, actualizar primero spec/plan.
>
> El **orden de ejecución en el tiempo** y el backlog con IDs Jira (`SL-*`) están en `5_roadmap.md`; el mapeo es 1-a-1 con las tareas `T*` de este documento.

**Convenciones:**
- IDs: `T<fase>.<n>`. La tarea de integración de cada fase es `T<fase>.INT`.
- Columna **Stream**: `BE-A` (Java: auth/negocio), `BE-B` (Java+Python: telemetría/eventos/push), `FE-A` (Flutter: auth/monitored), `FE-B` (Flutter: caregiver/IT), `ML` (transversal), `ALL` (equipo).
- Dependencias entre paréntesis. Los streams sin dependencias entre sí se ejecutan **en paralelo**.

---

## Fase 0 — Fundaciones

### Comunes

- [x] **T0.1** `ALL` — Revisar y aprobar en equipo los 4 documentos SDD + constitución. **Congelar contratos de spec §6 para la fase.** *(bloqueante para todo)*
- [x] **T0.2** `FE-A` — Renombrar la app a **SentiLife** en todas las plataformas según tabla de `3_plan.md` §3.
- [x] **T0.3** `ALL` — Actualizar `README.md` raíz: nombre, arquitectura, referencia a los 4 documentos SDD.

### Estructura Java (no existe — tarea inicial de creación)

- [ ] **T0.4** `BE-A` — **Crear desde cero la estructura `backend-java/`**: Spring Boot 3 + Java 21 (Spring Initializr: web, security, data-jpa, validation, actuator, postgresql), paquetes `com.sentilife.{auth,users,monitored,consent,telemetry,alerts,notifications,admin,ota,config}`, perfil `application-docker.yml`, Dockerfile multi-stage, `/actuator/health` respondiendo. *(ADR-01 — bloqueante para todo BE)*
- [ ] **T0.5** `BE-B` — Migraciones de esquema (Flyway) con las tablas de spec §5.1 (incluidas `paired_devices` y `push_tokens`); seed de usuario `IT_ADMIN`.

### Infraestructura y compose (premisa: un solo `docker compose up`)

- [ ] **T0.6** `BE-B` — Ampliar `docker-compose.yml` y `docker-compose.prod.yml` con: **backend-java**, RabbitMQ (management), InfluxDB 2.x, Prometheus, Grafana. Health checks en todos; variables nuevas en `.env.example` (`JWT_SECRET`, `INFLUX_TOKEN`, `RABBITMQ_PASSWORD`, `FIREBASE_SERVICE_ACCOUNT`). *(3_plan.md §5 premisa operativa)*
- [ ] **T0.7** `BE-B` — Carpeta `observability/`: `prometheus.yml` (scrape Java actuator + FastAPI) y Grafana provisionado (datasource + dashboard esqueleto versionado). *(RF-24, RF-25)*
- [x] **T0.8** `BE-B` — Reducir FastAPI a servicio de inferencia: `/predict`, `/health`, `/metrics`, `/model/info`, `/model/reload`; `/app/*` marcado para migración. *(ADR-06)*
- [x] **T0.9** `FE-A` — Base i18n en Flutter: `flutter_localizations` + ARB `es`/`en`, selector de idioma, migrar strings existentes. Desde aquí, prohibido hardcodear textos. *(RF-31, ADR-08)*
- [x] **T0.10** `FE-B` — Actualizar el **mock de Flutter** para implementar exactamente los contratos de spec §6 (auth, personas, telemetría, alertas, admin) — es la herramienta que desacopla FE de BE. *(3_plan.md §6 regla 1)*
- [x] **T0.11** `ALL` — Actualizar `Makefile` y `scripts/verify-local.sh`: `make up` levanta el stack completo y verifica todos los health checks; `make flutter-local` arranca la app contra la infra local.

### Integración

- [ ] **T0.INT** `ALL` — En una máquina limpia: `git clone` → `cp .env.example .env` → `docker compose up` → todos los servicios sanos → `make flutter-local` muestra la app. Documentar cualquier fricción en README.

---

## Fase 1 — Nivel Esencial (ML núcleo) 🟢

### ML / datos

- [x] **T1.1** `ML` — EDA SisFall completo (`Backend/notebooks/`): clases, histogramas X/Y/Z, correlación, sesgo edad/sexo, frecuencia de muestreo → `processed/sisfall/eda_output/`. *(ML-01)*
- [x] **T1.2** `ML` — Definir la **ventana** (tamaño, solape, frecuencia) y publicarla como contrato compartido entrenamiento ↔ inferencia ↔ app. Contrato v1.0.0 en `contracts/window_contract.json` + `contracts/window_contract.md`: 2.5 s, 50 Hz, 50% solape, 125 muestras/señal. *(ADR-05 — bloqueante T1.3, T1.7, T1.8)*
- [ ] **T1.3** `ML` — Pipeline de features reproducible: regenerar `processed/sisfall/` con ventanas + features estadísticas. (T1.2)
- [ ] **T1.4** `ML` — Baseline con split por sujeto (GroupKFold). *(ML-07)*
- [ ] **T1.5** `ML` — Primer modelo candidato (RF/XGBoost) con overfitting < 5%, recall de caídas priorizado. *(ML-02, ML-03)*
- [ ] **T1.6** `ML` — Informe técnico v1: métricas completas + ROC + confusión + feature importance + sesgo. *(ML-05)*

### Backend (paralelo a ML)

- [ ] **T1.7** `BE-B` — Integrar modelo en FastAPI: carga `model.pkl`, preprocesado idéntico al entrenamiento, respuesta spec §6.8. Eliminar `classify()` por umbrales. *(ML-04, RF-13)* (T1.2, T1.5)
- [ ] **T1.8** `BE-B` — Java: `POST /api/v1/telemetry/windows` v1 (sin consentimiento aún): valida payload → escribe InfluxDB → llama inferencia síncrona → devuelve predicción según spec §6.3. Medir latencia (histograma Prometheus). *(RF-12)* (T0.8)
- [ ] **T1.9** `BE-A` — Java: vinculación de dispositivo `POST /api/v1/devices/pair` + `pairingCode` en personas (spec §6.4).

### Frontend (paralelo, contra mock)

- [ ] **T1.10** `FE-A` — Captura de sensores reales (acelerómetro/giroscopio) y construcción de ventanas según contrato T1.2; envío continuo con cola local si no hay red. *(RF-10, RF-11)*
- [ ] **T1.11** `FE-A` — Pantalla MONITORED v1: estado de monitorización, última evaluación. *(RF-20)*

### Integración

- [ ] **T1.INT** `ALL` — Mock off: app → Java → InfluxDB → FastAPI → predicción real. Demo de caída simulada con el móvil; registrar latencia extremo a extremo medida.

---

## Fase 2 — Nivel Medio + perfiles + push 🟡

### ML

- [ ] **T2.1** `ML` — Comparativa ensembles (RF vs. GB vs. XGBoost) con GroupKFold/LOSO. *(ML-06, ML-07)*
- [ ] **T2.2** `ML` — Optuna sobre el mejor candidato; informe v2. *(ML-08)*

### Stream BE-A (auth y negocio)

- [ ] **T2.3** `BE-A` — Auth completa: register, login, refresh, JWT con roles, BCrypt, contrato spec §6.1. Tests. *(RF-01, RF-02, ADR-04)*
- [ ] **T2.4** `BE-A` — CRUD personas monitorizadas según spec §6.2 (formulario del cuidador). *(RF-03)*
- [ ] **T2.5** `BE-A` — Consentimiento: aceptar/revocar con versión+idioma; filtro que devuelve 403 en telemetría sin consentimiento activo. *(RF-05…RF-07)* (T2.4)
- [ ] **T2.6** `BE-A` — Migrar OTA (`/app/*`) de FastAPI a Java (spec §6.7). *(ADR-06, RF-23)*

### Stream BE-B (eventos, alertas, push)

- [ ] **T2.7** `BE-B` — RabbitMQ: exchanges/colas de spec §5.3; worker de inferencia; decidir camino crítico síncrono vs. cola con la medición de T1.8. *(ADR-02, RF-14)*
- [ ] **T2.8** `BE-B` — Alertas: persistencia, `GET /alerts`, `PATCH /alerts/{id}` → `feedback_labels` (spec §6.5). *(RF-14, RF-16, RF-17)*
- [ ] **T2.9** `BE-B` — **Push FCM**: `POST /devices/push-token`, servicio notificador (Firebase Admin SDK) consumiendo `alert.created`, payload spec §6.4, eventos de estado (monitorización on/off, consentimiento revocado). *(RF-27…RF-30, ADR-07)* (T2.8)
- [ ] **T2.10** `BE-B` — Admin: `GET /admin/history`, `GET /admin/export` (dataset etiquetado → `data/feedback/`), `GET/PATCH /admin/users`. *(RF-18, RF-19, RF-04, ML-09, ML-10)*

### Stream FE-A (monitored)

- [ ] **T2.11** `FE-A` — Login + navegación por rol (3 perfiles), sesión JWT con refresh. *(RF-20…RF-22)* 
- [ ] **T2.12** `FE-A` — Modal de **consentimiento** (primera ejecución, versión por idioma, revocación en ajustes) + flujo de vinculación con `pairingCode`. *(RF-05, RF-07)*
- [ ] **T2.13** `FE-A` — Modal de **transparencia de datos** (patrón proyecto 4): "tus predicciones y feedback se usan para reentrenar el modelo", enlazado desde consentimiento y ajustes. *(RF-32)*

### Stream FE-B (caregiver + IT)

- [ ] **T2.14** `FE-B` — Perfil CAREGIVER: formulario de registro de persona, lista con estado en tiempo casi real (`GET /telemetry/status/{id}`), historial. *(RF-21)*
- [ ] **T2.15** `FE-B` — Alertas en app: pantalla de detalle, confirmar/descartar con comentario, polling de respaldo. *(RF-15, RF-17)*
- [ ] **T2.16** `FE-B` — **Push en Flutter**: `firebase_messaging`, registro de token en login, notificación en background/terminated, tap → `AlertDetailScreen`. *(RF-27…RF-29)* (T2.9)
- [ ] **T2.17** `FE-B` — Perfil IT_ADMIN: historial global, export, enlace a Grafana. *(RF-22)*

### Integración

- [ ] **T2.INT** `ALL` — End-to-end real con cronómetro: cuidador registra persona → consentimiento → caída → **push en el móvil del cuidador < 5 s** → confirma → export IT contiene la muestra etiquetada. Verificar los 8 criterios de aceptación de spec §7 que apliquen.

---

## Fase 3 — Nivel Avanzado (producción) 🟠

- [ ] **T3.1** `BE-B` — `docker-compose.prod.yml` con el stack completo y puertos de `3_plan.md` §5. *(ML-11)*
- [ ] **T3.2** `BE-A` — CI: `mvn test` en `backend-ci.yml`, imágenes Java+FastAPI a Docker Hub, deploy EC2, nuevos secrets (incl. `FIREBASE_SERVICE_ACCOUNT`). *(RNF-07)*
- [ ] **T3.3** `BE-B` — Despliegue QA en EC2, Security Group (8005 público, resto interno). *(ML-13)*
- [ ] **T3.4** `BE-A`+`BE-B` — Suite de tests completa: Java (auth, consentimiento, permisos por rol, alertas, contrato de errores) y Python (preprocesado, métricas, contrato `/predict`). *(ML-14)*
- [ ] **T3.5** `BE-B` — Dashboard Grafana definitivo: latencia extremo a extremo, latencia `/predict`, colas, errores, entregas push. *(RF-25, RNF-01/02)*
- [ ] **T3.6** `BE-A` — Supresión GDPR end-to-end (Postgres + InfluxDB + tokens) con test. *(RF-08)*
- [ ] **T3.7** `FE-A`+`FE-B` — i18n completo es/en (incluidos textos legales versionados) + pulido de UX; revisar textos de push localizados por `locale` del token. *(RF-31)*
- [ ] **T3.8** `FE-B` — OTA apuntando al endpoint Java migrado; verificar auto-actualización en dispositivo real. *(RF-23)*
- [ ] **T3.INT** `ALL` — Push a `main` → despliegue automático → demo de caída sobre QA con dashboard en vivo, app en ambos idiomas y latencia verificada (si > 5 s, contingencias de `3_plan.md` §8).

---

## Fase 4 — Nivel Experto (MLOps) 🔴

- [ ] **T4.1** `ML` — MobiAct (si llegó): validación, EDA comparativo, `processed/combined/`. Si no: cerrar Plan B documentado. *(3_plan.md §4)*
- [ ] **T4.2** `ML` — CNN 1D / LSTM sobre ventanas crudas vs. mejor ensemble, mismo split por sujeto. *(ML-15)*
- [ ] **T4.3** `BE-B` — Registro de modelos: `ml/registry/` + tabla `model_registry`; FastAPI carga el `ACTIVE` y expone `/model/reload` (hot-reload sin reiniciar contenedores). *(ML-16, ADR-09)*
- [ ] **T4.4** `BE-B`+`ML` — **Reentrenamiento con datos reales** (patrón proyecto 4): `POST /admin/retrain` → job con fases `drift → training → reload` y estado consultable `GET /admin/retrain/status` (spec §6.6); decisión por recall de caídas con guardas de overfitting y split por sujeto. *(RF-33, ML-19, ADR-09)* (T2.10, T4.3)
- [ ] **T4.5** `FE-B` — Pantalla IT de MLOps: botón de reentrenamiento, polling de estado con fases y mensaje de decisión, historial de versiones de modelo. *(RF-33)* (T4.4)
- [ ] **T4.6** `BE-B` — A/B testing: ~20% del tráfico al `CANDIDATE`, métricas por versión en Prometheus/Grafana. *(ML-17)* (T4.3)
- [ ] **T4.7** `ML` — Monitoreo de data drift con panel y alerta en Grafana. *(ML-18)*
- [ ] **T4.8** `ALL` — Informe técnico final + presentación de negocio + presentación técnica. *(constitución §4)*
- [ ] **T4.INT** `ALL` — Demo experto: IT lanza reentrenamiento desde la app con feedback real acumulado → decisión visible (`promoted`/`candidate`) → dos modelos sirviendo tráfico comparados en Grafana → auto-reemplazo demostrado.

---

## Tablero de estado por nivel

| Nivel bootcamp | Fases | Estado |
|---|---|---|
| 🟢 Esencial | 0–1 | ⏳ |
| 🟡 Medio | 2 | 🔲 |
| 🟠 Avanzado | 3 | 🔲 |
| 🔴 Experto | 4 | 🔲 |

## Matriz rápida de paralelismo (Fase 2, la más cargada)

| | BE-A | BE-B | FE-A | FE-B |
|---|---|---|---|---|
| Semana 1 | T2.3 auth | T2.7 colas | T2.11 login | T2.14 caregiver |
| Semana 2 | T2.4/T2.5 personas+consent | T2.8/T2.9 alertas+push | T2.12/T2.13 modales | T2.15/T2.16 alertas+push |
| Cierre | T2.6 OTA | T2.10 admin | — | T2.17 IT |
| Juntos | | | | **T2.INT** |

---

## Estado del documento

| Campo | Valor |
|---|---|
| Estado | Draft v0.2 |
| Autores | Equipo Grupo 1 |
| Última actualización | 08/07/2026 |
