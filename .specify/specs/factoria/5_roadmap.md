# 5. Roadmap — SentiLife · SPRINT ÚNICO 8→15 JULIO (constitución completa)

> Documento operativo derivado de `4_task.md`. **Deadline: miércoles 15 de julio.** **HOY: domingo 12 de julio. Quedan 3 días de ejecución (dom 12 → mar 14) + entrega el miércoles 15.**
>
> **Mandato del equipo:** la constitución se cumple **a cabalidad — los cuatro niveles, Esencial a Experto — y la calidad no es negociable** (overfitting < 5%, split por sujeto, datasets con soporte académico, GDPR). Lo que se recorta son los extras autoimpuestos que **no** están en la constitución.

**Estado de los contratos: ✅ DEFINIDOS** en `2_spec.md` §6. Congelados desde el kickoff (SL-1). Cambio de contrato = PR al spec aprobado por 1 dev de cada lado.

---

## 0. ESTADO ACTUAL — DOM 12 (sincronizado 12/07/2026)

> Esta sección es la fuente de verdad de situación para todos los agentes. Actualizar aquí **antes** de cualquier PR.

### ✅ Completado (verificado en código)

| Stream | Completado | SL / Tarea |
|---|---|---|
| ALL | Kickoff + contratos congelados | SL-1 / T0.1 |
| ALL | README SentiLife + arquitectura | SL-4 / T0.3 |
| ALL | Makefile + scripts verify-local | SL-12 / T0.11 |
| BE-B | FastAPI reducido a inferencia pura | SL-7 / T0.8 |
| BE-B | **Modelo real XGBoost en `/predict`** (features.py + model.py) | SL-20 / T1.7 |
| FE-A | Renombrado SentiLife | SL-8 / T0.2 |
| FE-A | i18n base español | SL-9 / T0.9 |
| FE-A | **Captura sensores + ventanas (125 muestras@50Hz)** | SL-23 / T1.10 |
| FE-B | Mock de contratos completo (auth/personas/telemetría/alertas) | SL-10 / T0.10 |
| ML | EDA SisFall completo (sesgo edad/sexo documentado) | SL-13 / T1.1 |
| ML | Contrato de ventana v1.0.0 publicado | SL-14 / T1.2 |
| ML | Pipeline features (56.313 ventanas, 116 features) | SL-16 / T1.3 |
| ML | **Baseline GroupKFold / LOSO sin fuga de sujetos** | SL-17 / T1.4 |
| ML | **XGBoost: PR-AUC=0.901, recall=83.2%, overfitting<3%** | SL-18 / T1.5 |
| ML | **Informe técnico v1** (`Backend/docs/informe_tecnico_v1.md`) | — / T1.6 |

### ⚠ Bloqueado — BE Java no está en el repo

> El equipo BE-A/BE-B Java está trabajando en local pero **no ha hecho push**. Hasta que suban el código, todas las tareas que dependen de Java quedan en ⚠.

| SL | Tarea bloqueada | Desbloquea |
|---|---|---|
| SL-2 | Estructura backend-java (Spring Boot 3) | todo el BE Java |
| SL-3 | Flyway + seed | SL-21, SL-26 |
| SL-5 | Compose completo (+Java+RabbitMQ+Grafana) | T0.INT |
| SL-15 / T0.INT | Fundaciones integradas | Fase 1 completa |
| SL-21 | POST /telemetry/windows Java | T1.8, T1.INT |
| SL-22 | /devices/pair Java | T1.9 |
| SL-25 / T1.INT | Integración real app→Java→FastAPI | Fase 2 |
| SL-26 | Auth JWT | SL-27, SL-28, SL-30 |
| SL-27 | CRUD personas | SL-28, SL-31 |
| SL-28 | Consentimiento + 403 | SL-34, SL-43 |
| SL-34 | Alertas + feedback_labels | SL-35, SL-36, SL-55 |
| SL-44 | CI mvn test | SL-45, SL-46 |
| SL-45 / T3.3 | Deploy QA EC2 | T3.INT, T4.INT |

### 🔲 Pendiente (sin bloqueo Java — ejecutable HOY)

| SL | Tarea | Stream | Día plan | Impacto |
|---|---|---|---|---|
| SL-41 / T2.1 | Ensembles RF+GB+XGBoost GroupKFold/LOSO | ML | dom 12 | 🟡 Nivel Medio |
| SL-42 / T2.2 | Optuna + informe v2 | ML | dom 12 | 🟡 Nivel Medio |
| SL-53 / T4.2 | CNN 1D/LSTM vs. ensemble (mismo split) | ML | lun 13 | 🔴 Nivel Experto |
| SL-54 / T4.3 | Registry modelos + hot-reload FastAPI | BE-B | dom 12 | 🔴 Base retrain |
| SL-55 / T4.4 | Retrain + auto-reemplazo por métricas | BE-B+ML | lun 13 | 🔴 Experto core |
| SL-57 / T4.6 | A/B testing ~20% tráfico CANDIDATE | BE-B | mar 14 | 🔴 Experto |
| SL-58 / T4.7 | Data drift + panel Grafana | ML | mar 14 | 🔴 Experto |
| SL-47 / T3.5 | Dashboard Grafana definitivo | BE-B | mar 14 | 🟠 Avanzado |
| SL-24 / T1.11 | Pantalla MONITORED v1 Flutter | FE-A | dom 12 | 🟢 Esencial FE |
| SL-11 | Navegación 3 perfiles Flutter | FE-B | dom 12 | 🟡 Medio FE |
| SL-31 / T2.14 | Perfil CAREGIVER Flutter | FE-B | dom 12 | 🟡 Medio FE |
| SL-40 / T2.17 | Perfil IT_ADMIN Flutter | FE-B | lun 13 | 🟡 Medio FE |
| SL-36 / T2.10 | Export dataset etiquetado (admin API mock) | BE-B | dom 12 | 🟡 Medio |
| SL-56 / T4.5 | Pantalla MLOps IT Flutter | FE-B | lun 13 | 🔴 SHOULD |
| SL-51 / T3.INT | Demo QA + video respaldo | ALL | mar 14 | Entrega |
| SL-59 / T4.8 | Informe final + presentaciones | ALL | mié 15 | Entrega |

---

## 0b. GATE DE PR / PUSH — **Requisito fundamental · vigente desde dom 12**

> **Ningún PR se mergea a `dev` ni a `main` sin cumplir este checklist.** Esto es obligatorio para todos los agentes y devs del equipo. El agente que abre el PR debe verificar cada punto y marcarlo en la descripción del PR.

```
## Checklist de PR (copiar en la descripción)

### Trazabilidad
- [ ] El título del commit y del PR tiene formato `SL-xx: descripción breve`
- [ ] La tarea `T*.x` correspondiente está marcada `[x]` en `4_task.md`
- [ ] El SL correspondiente está en ✅ en `5_roadmap.md` §4 (tablero)
- [ ] La sección "ESTADO ACTUAL" de `5_roadmap.md` §0 refleja el nuevo estado

### Calidad
- [ ] Los tests existentes pasan: `make test` (o `pytest` + `flutter test`)
- [ ] No hay regresiones en el contrato de `/predict` (fixtures en `Backend/tests/`)
- [ ] Si se modificaron features del modelo: el pipeline de entrenamiento está sincronizado
  con `api/inference/features.py` y el `window_contract.json` no cambia
- [ ] Si se modificó un contrato de spec §6: aprobado por al menos 1 dev de cada lado

### Modelo / ML (solo PRs con cambios en `Backend/ml/` o `Backend/api/inference/`)
- [ ] Overfitting validado: |CV_PR-AUC - Test_PR-AUC| < 5 pp
- [ ] Split por sujeto (GroupKFold/LOSO) verificado — ningún subject_id en train Y test
- [ ] Métricas del modelo nuevo ≥ modelo anterior en test (recall_fall y PR-AUC)
- [ ] `model.pkl` regenerado y commitado (o en artefacto CI)

### BE Java (solo PRs con cambios en `backend-java/`)
- [ ] `mvn test` pasa localmente
- [ ] `/actuator/health` responde en Docker
- [ ] `docker compose up` levanta sin errores el stack completo
```

> **Regla de emergencia (3 días finales):** si el PR es un fix urgente bloqueante, puede mergear con los tests obligatorios (trazabilidad + `make test`) pero debe abrir un issue inmediato con los checks faltantes.

---

## 1. Alcance: qué es innegociable y dónde está la flexibilidad

### Innegociable (constitución §3 — los 4 niveles)

| Nivel | Ítems | Dónde cae en el calendario |
|---|---|---|
| 🟢 Esencial | EDA completo · modelo funcional · **overfitting < 5%** · FastAPI · informe técnico completo | mié 8 → vie 10 |
| 🟡 Medio | Ensembles (RF/GB/XGBoost) · validación cruzada por sujeto (LOSO/GroupKFold) · Optuna · feedback desde la app · recogida de datos nuevos vía API | vie 10 → dom 12 |
| 🟠 Avanzado | Todo dockerizado · registros en BD · deploy en nube · tests unitarios | sáb 11 → lun 13 |
| 🔴 Experto | **Red neuronal (CNN 1D/LSTM)** · **A/B testing** · **data drift** · **auto-reemplazo por métricas** | dom 12 → mar 14 |

### Flexible (extras nuestros, NO constitución — aquí se ajusta si el tiempo aprieta)

| Extra | Decisión sprint |
|---|---|
| InfluxDB | **Fallback activado (ADR-03):** telemetría en PostgreSQL. Cumple "guardado en BD" de la constitución igual. Post-entrega |
| RabbitMQ | Solo `alert.created` → notificador push. Predicción síncrona HTTP (latencia manda) |
| Migrar OTA a Java | Pospuesto — OTA sigue en FastAPI, funciona |
| Push FCM | SHOULD con gate horario; fallback polling cumple "feedback desde la app" igual |
| i18n | Español completo; inglés solo si sobra tiempo |
| Pantalla MLOps en app | SHOULD — el nivel Experto se puede demostrar por API/Grafana si falta la pantalla |

> **Regla del sprint:** los ítems de constitución no se recortan **ni se falsean**: un LOSO mal hecho o un drift de mentira es peor que llegar justos. Si un ítem de constitución peligra, se recorta ANTES cualquier extra y se reasigna gente.

---

## 2. Calendario día a día (8 días de ejecución)

### 🗓 MIÉ 8 (HOY) — Fundaciones en paralelo

| Quién | Tareas | Entregable al final del día |
|---|---|---|
| **Todos (30 min)** | SL-1 kickoff: aprobar este roadmap, congelar contratos, repartir streams | Acta en `docs/daily/` |
| BE-A | SL-2 estructura `backend-java/` (Initializr, Dockerfile) | `/actuator/health` UP en Docker |
| BE-B | SL-5 compose (+Java, +RabbitMQ, +Prometheus, +Grafana) · SL-7 FastAPI solo inferencia | `docker compose up` todo verde |
| FE-A | SL-8 renombrado SentiLife → SL-9 i18n base (es) | APK "SentiLife" |
| FE-B | SL-10 **mock de contratos** | FE desbloqueado al 100% |
| ALL | SL-12 flujo local (`make up` + health checks + `make flutter-local`) | Arranque local homologado |
| ML | SL-13 EDA SisFall — **ruta crítica, prioridad absoluta** | Notebook avanzado |

### 🗓 JUE 9 — Contrato de ventana + primeros endpoints

| Quién | Tareas | Entregable |
|---|---|---|
| BE-A | SL-3 Flyway (tablas §5.1 + `telemetry_windows`) + seed → arranca SL-26 auth | Migraciones corriendo |
| BE-B | SL-21 `POST /telemetry/windows`: valida → Postgres → HTTP síncrono FastAPI → §6.3, con histograma de latencia | Endpoint con modelo dummy |
| FE-A | SL-23 sensores + ventanas (provisional 2.5 s@50 Hz hasta SL-14) | Streaming contra mock |
| FE-B | SL-11 navegación 3 perfiles → SL-31 perfil CAREGIVER | Pantallas navegables |
| ML | SL-14 **contrato de ventana** · SL-16 pipeline de features | `processed/` regenerado |
| **Cierre** | **T0.INT:** clone limpio → compose up → verde | Fundaciones cerradas |

### 🗓 VIE 10 — Modelo Esencial + auth (cierre nivel 🟢)

| Quién | Tareas | Entregable |
|---|---|---|
| BE-A | SL-26 auth completa (JWT, roles, BCrypt) + SL-27 CRUD personas | Contratos §6.1/§6.2 reales |
| BE-B | SL-20 modelo real en FastAPI · SL-22 `/devices/pair` | `/predict` con model.pkl |
| FE-A | SL-24 pantalla MONITORED + SL-37 modal consentimiento | Flujo monitored (mock) |
| FE-B | SL-32 alertas + feedback → SL-40 perfil IT | Flujo caregiver (mock) |
| ML | SL-17 baseline por sujeto → SL-18 **modelo < 5% overfitting** · **noche: lanzar SL-41 ensembles + Optuna en background** | model.pkl entregado; 🟢 cerrado |
| **Cierre** | **T1.INT parcial:** app → Java → FastAPI → predicción real | Núcleo demostrable |

### 🗓 SÁB 11 — Ciclo completo: consentimiento, alertas, push (nivel 🟡 funcional)

| Quién | Tareas | Entregable |
|---|---|---|
| BE-A | SL-28 consentimiento + filtro 403 · SL-48 supresión GDPR (cascada Postgres) | GDPR demostrable |
| BE-B | SL-34 alertas + `feedback_labels` · SL-35 push FCM (gate 16:00 → fallback polling) | Alerta llega al cuidador |
| FE-A | SL-30 login real por rol (mock off en auth) · SL-38 modal transparencia | Sesión JWT real |
| FE-B | SL-39 push Flutter (test consola Firebase desde la mañana) | Notificación background |
| ML | Supervisar Optuna/LOSO · **preparar y lanzar SL-53 CNN 1D sobre ventanas crudas (entrena de noche)** | Ensembles cerrando; NN en marcha |
| **Cierre** | **T2.INT:** registro → consentimiento → caída → alerta → confirmar → dato etiquetado | **MVP funcional en local** |

### 🗓 DOM 12 — Infra Experto + informe (nivel 🟡 cerrado)

| Quién | Tareas | Entregable |
|---|---|---|
| BE-A | SL-44 CI con mvn test · SL-46 tests Java (auth, roles, consent 403) | CI verde |
| BE-B | SL-54 **registry de modelos + hot-reload** (`model_registry`, FastAPI carga `ACTIVE`, `/model/reload`) | Base del auto-reemplazo |
| FE-A/FE-B | Flecos de pantallas · export IT desde app (SL-36) | Flujos completos |
| ML | SL-42 cierre Optuna → **informe técnico v2** (Esencial+Medio: métricas, ROC, confusión, LOSO, hiperparámetros) · evaluar CNN de la noche | 🟡 cerrado con evidencia |
| **Cierre** | Registry funcionando en local; resultados NN preliminares | |

### 🗓 LUN 13 — Nivel Experto I: retrain + auto-reemplazo + deploy (nivel 🟠 cerrado)

| Quién | Tareas | Entregable |
|---|---|---|
| BE-A | Apoyo a tests + fixes de T2.INT | Suite estable |
| BE-B | SL-45 **deploy QA EC2** stack completo (fallback SSH manual si CI Java se atasca) | QA en vivo; 🟠 cerrado |
| BE-B+ML | SL-55 **retrain con feedback real + decisión por métricas** (patrón proyecto 4): `POST /admin/retrain` → `drift → training → reload` → `promoted/candidate/discarded` por **recall de caídas** con guardas | ML-19 auto-reemplazo real |
| FE-B | SL-56 pantalla MLOps IT (botón retrain + polling estado) — SHOULD | Experto visible en app |
| ML | SL-53 cierre CNN 1D/LSTM: comparativa honesta vs. mejor ensemble (mismo split por sujeto) | ML-15 cerrado |
| **Cierre** | Retrain end-to-end demostrado en local | |

### 🗓 MAR 14 — Nivel Experto II: A/B + drift + freeze (nivel 🔴 cerrado)

| Quién | Tareas | Entregable |
|---|---|---|
| BE-B | SL-57 **A/B testing**: ~20% tráfico al `CANDIDATE`, métricas por versión en Prometheus | ML-17 cerrado |
| ML | SL-58 **data drift**: monitor de distribuciones de features de entrada + panel/alerta Grafana | ML-18 cerrado |
| BE-B | SL-47 dashboard Grafana definitivo (latencia e2e, /predict, alertas, versiones de modelo) | Observabilidad completa |
| FE-A/FE-B | Pulido UX · APK release · (stretch: inglés) | Build final |
| **14:00** | **FEATURE FREEZE** — solo bugs | |
| **Cierre** | **T3/T4.INT:** demo completa sobre QA cronometrada y **grabada en video** (respaldo) · informe final integrado (incl. NN, A/B, drift) | 🔴 cerrado |

### 🗓 MIÉ 15 — ENTREGA

- **Mañana:** ensayo de demo ×2 · SL-59 presentación negocio + técnica · README final · congelar `main`.
- **Demo:** caída real → push al cuidador → feedback → **retrain desde IT → decisión promoted/candidate → A/B y drift en Grafana**.
- **Plan B:** video del D14 + stack local por compose si QA falla.

---

## 3. Ruta crítica y gates

```
SL-13 EDA → SL-14 ventana → SL-16 features → SL-18 modelo 🟢 → SL-41 ensembles 🟡 ─→ SL-53 CNN 🔴
                                     │                              (background)        (background)
SL-2 Java → SL-3 → SL-21 telemetría → SL-26 auth → SL-28/34 alertas → SL-54 registry → SL-55 retrain → SL-57 A/B 🔴
                                                        │
                                              T2.INT (sáb) → deploy (lun) → T3/T4.INT (mar) → DEMO (mié)
```

- **ML es ruta crítica los 3 primeros días; BE-B lo es los 3 últimos.** Los entrenamientos largos (Optuna, CNN) corren **de noche/background** — se lanzan al cierre del día, nunca bloquean la jornada.
- **Gates horarios (pasada la hora, fallback sin discusión):** push sáb 11 16:00 → polling · pantalla MLOps lun 13 EOD → demo Experto por API/Grafana · feature freeze mar 14 14:00.
- **Si un ítem de constitución se atasca >medio día:** se avisa, se recorta un extra (§1 flexible) y se reasigna una persona. Los niveles no se negocian; los extras sí.
- Calidad protegida: LOSO/split por sujeto en TODOS los modelos incluida la NN; drift real sobre features de entrada; auto-reemplazo con guardas (recall + overfitting), no un `if` decorativo.

---

## 4. Backlog del sprint — TABLERO DE ESTADO (fuente de verdad de ejecución)

> **Protocolo del agente (constitución §7):** los devs no escriben código — dirigen y aprueban. El agente ejecuta **solo** tareas de esta tabla, en orden de día y dependencias. Por cada tarea: ejecutar → verificar CA → actualizar **Estado** aquí (y checkbox en `4_task.md`) → **un commit** con formato `SL-xx: descripción`. Si la ejecución obliga a cambiar spec/plan, se actualiza en el mismo commit.
>
> Estados: 🔲 pendiente · ⏳ en curso · ✅ hecho · ⚠ bloqueado (con nota) · ✂ cortado.

| ID | Título | Stream | Prio | Día plan | Depende | Estado · dom 12 |
|---|---|---|---|---|---|---|
| SL-1 | Kickoff: roadmap + contratos congelados | ALL | MUST | mié 8 | — | ✅ |
| SL-4 | README SentiLife + arquitectura + SDD | ALL | MUST | mié 8 | SL-8 | ✅ |
| SL-7 | FastAPI reducido a inferencia | BE-B | MUST | mié 8 | SL-1 | ✅ |
| SL-8 | Renombrado SentiLife | FE-A | MUST | mié 8 | SL-1 | ✅ |
| SL-9 | i18n base (es) | FE-A | SHOULD | mié 8 | SL-8 | ✅ |
| SL-10 | Mock de contratos completo | FE-B | MUST | mié 8 | SL-1 | ✅ |
| SL-12 | Flujo local Makefile + health checks | ALL | MUST | mié 8 | SL-5 | ✅ (parcial, sin Java) |
| SL-13 | EDA SisFall (🟢) | ML | MUST | mié 8 | SL-1 | ✅ |
| SL-2 | Estructura backend-java (Spring Boot 3) | BE-A | MUST | mié 8 | SL-1 | ⚠ en local, sin push |
| SL-5 | Compose completo (+Java/RabbitMQ/Prom/Grafana) | BE-B | MUST | mié 8 | SL-2 | ⚠ bloqueado SL-2 |
| SL-14 | Contrato de ventana v1.0.0 | ML | MUST | jue 9 | SL-13 | ✅ |
| SL-16 | Pipeline de features (56.313 ventanas, 116 feat) | ML | MUST | jue 9 | SL-14 | ✅ |
| SL-23 | Sensores + ventanas Flutter (cola offline) | FE-A | MUST | jue 9 | SL-10 | ✅ |
| SL-3 | Flyway + seed (+`telemetry_windows`) | BE-A | MUST | jue 9 | SL-2 | ⚠ bloqueado SL-2 |
| SL-21 | POST /telemetry/windows (síncrono, Postgres) | BE-B | MUST | jue 9 | SL-3 | ⚠ bloqueado SL-3 |
| SL-11 | Navegación 3 perfiles Flutter | FE-B | MUST | jue 9 | SL-10 | ✅ |
| SL-31 | Perfil CAREGIVER Flutter | FE-B | MUST | jue 9 | SL-11 | ✅ |
| SL-15 | T0.INT fundaciones | ALL | MUST | jue 9 | SL-2…SL-11 | ⚠ bloqueado SL-2 |
| SL-17 | Baseline por sujeto (GroupKFold, LOSO) | ML | MUST | vie 10 | SL-16 | ✅ |
| SL-18 | Modelo < 5% overfitting + informe v1 (🟢) | ML | MUST | vie 10 | SL-17 | ✅ XGBoost PR-AUC=0.901 |
| SL-20 | Modelo real en FastAPI — features.py+model.py (🟢) | BE-B | MUST | vie 10 | SL-18 | ✅ |
| SL-24 | Pantalla MONITORED v1 Flutter | FE-A | MUST | vie 10 | SL-23 | ✅ |
| SL-37 | Modal consentimiento Flutter | FE-A | MUST | vie 10 | SL-24 | ✅ |
| SL-32 | Alertas + feedback UI Flutter | FE-B | MUST | vie 10 | SL-31 | ✅ |
| SL-40 | Perfil IT_ADMIN Flutter | FE-B | SHOULD | vie 10 | SL-32 | ✅ |
| SL-26 | Auth JWT completa | BE-A | MUST | vie 10 | SL-3 | ⚠ bloqueado SL-3 |
| SL-27 | CRUD personas | BE-A | MUST | vie 10 | SL-26 | ⚠ bloqueado SL-26 |
| SL-22 | /devices/pair Java | BE-B | MUST | vie 10 | SL-3 | ⚠ bloqueado SL-3 |
| SL-25 | T1.INT núcleo real (app→Java→FastAPI) | ALL | MUST | vie 10 | SL-20, SL-26 | ⚠ bloqueado SL-26 |
| SL-41 | Ensembles RF+GB+XGBoost GroupKFold/LOSO (🟡) | ML | MUST | dom 12 | SL-18 | ✅ |
| SL-42 | Optuna + informe v2 (🟡) | ML | MUST | dom 12 | SL-41 | ✅ |
| SL-54 | Registry modelos + hot-reload FastAPI (🔴) | BE-B | MUST | dom 12 | SL-20 | ✅ |
| SL-36 | Export dataset etiquetado — script Python (🟡) | BE-B | MUST | dom 12 | SL-20 | ✅ (sin Java) |
| SL-28 | Consentimiento + 403 | BE-A | MUST | sáb 11 | SL-27 | ⚠ bloqueado SL-27 |
| SL-48 | Supresión GDPR | BE-A | MUST | sáb 11 | SL-28 | ⚠ bloqueado SL-28 |
| SL-34 | Alertas + feedback_labels (🟡) | BE-B | MUST | sáb 11 | SL-21 | ⚠ bloqueado SL-21 |
| SL-35 | Push FCM backend | BE-B | SHOULD | sáb 11 | SL-34 | ⚠ bloqueado SL-34 |
| SL-30 | Login real por rol Flutter | FE-A | MUST | sáb 11 | SL-26 | ⚠ bloqueado SL-26 |
| SL-38 | Modal transparencia Flutter | FE-A | SHOULD | sáb 11 | SL-37 | ✅ |
| SL-39 | Push Flutter | FE-B | SHOULD | sáb 11 | SL-32 | 🔲 |
| SL-43 | T2.INT MVP completo local | ALL | MUST | sáb 11 | SL-28…SL-39 | ⚠ bloqueado SL-28 |
| SL-44 | CI mvn test | BE-A | MUST | dom 12 | SL-26 | ⚠ bloqueado SL-26 |
| SL-46 | Tests Java (auth/roles/consent) (🟠) | BE-A | MUST | dom 12 | SL-43 | ⚠ bloqueado SL-43 |
| SL-53 | CNN 1D/LSTM vs. ensemble (🔴) | ML | MUST | lun 13 | SL-41 | 🔲 **LUN** |
| SL-55 | Retrain + auto-reemplazo por métricas (🔴) | BE-B+ML | MUST | lun 13 | SL-54, SL-36 | 🔲 **LUN** |
| SL-56 | Pantalla MLOps IT Flutter (SHOULD) | FE-B | SHOULD | lun 13 | SL-55 | 🔲 |
| SL-45 | Deploy QA EC2 (🟠) | BE-B | MUST | lun 13 | SL-44 | ⚠ bloqueado SL-44 |
| SL-57 | A/B testing ~20% tráfico CANDIDATE (🔴) | BE-B | MUST | mar 14 | SL-54 | 🔲 |
| SL-58 | Data drift + panel Grafana (🔴) | ML | MUST | mar 14 | SL-55 | 🔲 |
| SL-47 | Dashboard Grafana definitivo (🟠) | BE-B | MUST | mar 14 | SL-20 | 🔲 |
| SL-51 | T3/T4.INT demo QA + video respaldo | ALL | MUST | mar 14 | SL-45, SL-55…SL-58 | ⚠ parcial (local si SL-45 falla) |
| SL-59 | Informe final + 2 presentaciones | ALL | MUST | mié 15 | SL-51 | 🔲 |
| SL-60 | DEMO FINAL | ALL | MUST | mié 15 | todo | 🔲 |

**Post-entrega** (extras nuestros, no constitución): InfluxDB, OTA a Java, inglés, MobiAct/combined (SL-52), gestión avanzada de usuarios admin, wearables.

---

## 5. Modelo de trabajo del sprint

- **El agente ejecuta, el equipo dirige.** Los devs no escriben código: lanzan las tareas al agente por ID (`ejecuta SL-2`), revisan el resultado contra los CA y aprueban. Los "streams" (BE-A, FE-B…) indican qué persona supervisa cada frente, no quién teclea.
- El agente sigue el protocolo de la constitución §7: solo tareas del backlog, estado actualizado en §4, un commit por tarea, SDD actualizado si la realidad cambia.
- **Arranque hoy:** SL-1 (kickoff humano, 30 min) → después, en paralelo: SL-2, SL-5+SL-7, SL-8→SL-9, SL-10 y SL-13.
- **Compromiso de finde confirmado en el kickoff** — sáb 11 y dom 12 son días de trabajo del sprint, con los entrenamientos pesados corriendo de noche.

---

## Estado del documento

| Campo | Valor |
|---|---|
| Estado | v4.0 — sincronizado dom 12/07, gate de PR añadido, estados reales |
| Autores | Equipo Grupo 1 |
| Última actualización | 12/07/2026 |
| Próxima revisión obligatoria | Al completar cada SL — actualizar §0 y §4 antes del PR |
