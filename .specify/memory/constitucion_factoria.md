# CONSTITUCIÓN DEL PROYECTO: SENTILIFE (Factoría F5 — Grupo 1)

> Documento de gobierno del proyecto. Toda especificación SDD (`.specify/specs/factoria/`) debe ser coherente con esta constitución. Si hay conflicto, gana la constitución; si la constitución queda obsoleta, se actualiza aquí primero.

## 1. OBJETIVO DEL PROYECTO (FACTORÍA F5)

Desarrollo integral de **SentiLife**, una plataforma de monitorización y mejora de la calidad de vida asistida por Inteligencia Artificial, superando todos los niveles de exigencia del bootcamp hasta llegar al nivel **Experto**.

- **Caso de uso núcleo (MVP):** detección de caídas en **tiempo real** (latencia en segundos) a partir de telemetría IMU (acelerómetro y giroscopio), clasificando "Caída" vs. "Actividades de la Vida Diaria" (ADL).
- **Visión ampliada:** aprovechar toda la data disponible en los datasets (actividades diarias, señales fisiológicas y de contexto: frecuencia cardíaca, temperatura, luz) para monitorizar y mejorar la calidad de vida de la persona, con un alcance bien acotado por fases.
- **Entregable principal:** app móvil (Flutter) con 3 perfiles de usuario (persona monitorizada, cuidador, área IT), conectada a un backend de negocio en **Java (Spring Boot)** y un servicio de inferencia ML en **Python (FastAPI)**.

## 2. STACK TECNOLÓGICO Y HERRAMIENTAS

| Capa | Tecnología | Rol |
|---|---|---|
| Análisis y modelado (EDA/ML) | Python · Pandas · Scikit-learn · XGBoost | Notebooks, entrenamiento, informes |
| Servicio de inferencia | **FastAPI (Python)** | Sirve el modelo (`/predict`), latencia crítica |
| Backend de negocio | **Java 21 · Spring Boot** | APIs REST, autenticación JWT, roles, gestión de usuarios/consentimientos/alertas |
| Mensajería / eventos | **RabbitMQ** | Bus de eventos: telemetría, predicciones, alertas |
| Base de datos relacional | **PostgreSQL** | Usuarios, roles, consentimientos, personas monitorizadas, alertas, versiones OTA, registro de modelos |
| Base de datos de series temporales | **InfluxDB** | Telemetría de sensores en tiempo real |
| Observabilidad | **Prometheus + Grafana** | Métricas de API, latencia de inferencia, dashboards |
| Frontend | Flutter | Recogida de sensores, visualización, consentimiento, 3 perfiles |
| Infraestructura | Docker · GitHub Actions · AWS EC2 | Contenedores, CI/CD, despliegue |

**Regla de arquitectura:** el modelo ML se sirve siempre a través del servicio de inferencia FastAPI (requisito del bootcamp). El backend Java orquesta el negocio y delega la predicción en ese servicio. Flutter nunca llama a la inferencia directamente en producción.

## 3. NIVELES DE ENTREGA (ROADMAP DEL EQUIPO)

### 🟢 Nivel Esencial
- [ ] Modelo de machine learning funcional que clasifique los datos de los sensores (Caída vs. ADL).
- [ ] Análisis exploratorio de los datos (EDA) con visualizaciones relevantes (matriz de correlación, histogramas de señales X,Y,Z).
- [ ] Overfitting inferior al **5%** (diferencia mínima entre métricas de entrenamiento y validación).
- [ ] Productivización de la solución conectando el modelo a través de **FastAPI** (servicio de inferencia detrás del backend Java).
- [ ] Informe técnico del rendimiento del modelo (accuracy, recall, precision, F1 score, curva ROC, matrices de confusión, feature importance).

### 🟡 Nivel Medio
- [ ] Implementación de modelos con técnicas de **ensemble** (Random Forest, Gradient Boosting, XGBoost).
- [ ] Uso de técnicas de **Validación Cruzada** (K-Fold, Leave-One-Out — split por sujeto/LOSO obligatorio en este dominio).
- [ ] Optimización de hiperparámetros (GridSearch, RandomSearch, Optuna).
- [ ] Sistema de **recogida de feedback** desde la app en Flutter para monitorizar la performance del modelo.
- [ ] Sistema de **recogida de datos nuevos** a través de la API para futuros reentrenamientos (área IT).

### 🟠 Nivel Avanzado
- [ ] Versión completamente **dockerizada** del programa (backend Java + inferencia + colas + DBs + observabilidad).
- [ ] Guardado en **bases de datos** de los registros recogidos por la aplicación (PostgreSQL + InfluxDB).
- [ ] **Despliegue** de la API y las bases de datos en la nube.
- [ ] Inclusión de **test unitarios** (backend Java, servicio de inferencia, preprocesamiento y métricas).

### 🔴 Nivel Experto
- [ ] Experimentos o despliegues con modelos de **redes neuronales** (ej. LSTM o CNN 1D para series temporales).
- [ ] Sistemas de **entrenamiento y despliegue automático (MLOps)**:
  - [ ] **A/B Testing** para comparar modelos en producción.
  - [ ] Monitoreo de **Data Drift** para detectar cambios en los patrones de los acelerómetros.
  - [ ] **Auto-reemplazo de modelos** condicionado a la superación de métricas predefinidas.

## 4. ENTREGABLES ADICIONALES
- Repositorio en GitHub ordenado en ramas y con commits limpios.
- Informe técnico de rendimiento.
- Presentación orientada a negocio y presentación técnica del código.
- SDD formal completo: `1_intent.md` → `2_spec.md` → `3_plan.md` → `4_task.md` en `.specify/specs/factoria/`.

## 5. CONVENCIÓN DE DATOS (OBLIGATORIA)

Toda la telemetría del proyecto vive bajo `Backend/data/` con **estructura espejo por fuente**:

```
data/
├── raw/           # originales sin modificar
│   ├── sisfall/
│   └── mobiact/   # candidato DS-02 (académico)
├── processed/     # derivados por dataset (CSV, EDA, features)
│   ├── sisfall/
│   ├── mobiact/
│   └── combined/  # solo uniones documentadas entre fuentes
└── feedback/      # datos runtime desde la app
```

**Reglas:**
1. Un dataset = **misma carpeta** en `raw/` y `processed/` (ej. `sisfall/`, `mobiact/`).
2. **Prohibido** mezclar CSVs de distintas fuentes en la raíz de `processed/`.
3. Datasets combinados van **solo** en `processed/combined/`, nunca en crudo.
4. **Prohibidos los datos mock/sintéticos en la app**: los servicios Flutter solo consumen el backend real; los tests usan test doubles (`MockClient`). Nunca datos fake en `data/`.
5. Detalle operativo: `Backend/data/README.md`.

## 6. CRITERIOS DE DATASETS (OBLIGATORIO — FACTORÍA F5 Y MÁSTER IA SANITARIA)

Todo dataset usado para entrenamiento, evaluación o citación en informes **debe cumplir los tres requisitos**:

| Criterio | Qué exige |
|---|---|
| **Paper** | Publicación revisada por pares o repositorio institucional con documentación del protocolo |
| **Consentimiento informado** | Estudio con aprobación ética / consentimiento documentado de participantes |
| **Citación en la comunidad** | Aparece en revisiones sistemáticas, benchmarks o papers recientes del dominio |

**Prohibido** usar como fuente de ML:
- Marketplaces sin trazabilidad académica (Kaggle genérico, CSVs anónimos, datos generados sin protocolo)
- Datasets sin metadatos de sujetos cuando el dominio lo requiera
- Fuentes que no puedan citarse en un paper o TFM con rigor

**Datasets descartados:**
- **Kaggle `zara2099/real-time-patient-fall-detection-data`** — dado de baja por ausencia de soporte académico verificable.

**Stack aprobado (2026-07-05):**
- **DS-01 SisFall** — activo (benchmark IMU cintura)
- **DS-02 MobiAct** — candidato (smartphone IMU, complemento a SisFall)
- **DS-combined** — solo tras validar fuentes individuales y documentar unión en SDD

La elección de datasets es **bloqueante** para el SDD y el entrenamiento. Sin fuentes válidas, no se entrena ni se publica.

## 7. PROTOCOLO DE EJECUCIÓN CON AGENTES DE IA (OBLIGATORIO)

El desarrollo se ejecuta mediante **agentes de IA**; el equipo humano dirige, revisa y aprueba. Reglas para cualquier agente que trabaje en este repo:

1. **Solo se ejecutan tareas del backlog** (`4_task.md`, IDs `T*` / opcional `SL-*`). Nada fuera del backlog: si falta una tarea, primero se añade a `4_task.md` y luego se ejecuta.
2. **Una tarea = un commit**, con el ID al inicio: `T3.4: MockMvc permisos por rol` o `SL-46: …`. No mezclar tareas en un commit.
3. **Actualizar el estado al terminar cada tarea:** checkbox `[x]` en `4_task.md` (y sección Estado actual / cola). La actualización de estado va incluida en el commit de la tarea.
4. **El SDD es la fuente de verdad:** si al ejecutar una tarea la realidad contradice `2_spec.md` o `3_plan.md` (contrato, decisión, fallback), se actualiza el documento en el mismo commit, marcando la decisión (⚠) — nunca se deja divergir código y documentación.
5. **Criterios de aceptación:** una tarea no se marca ✅ sin verificar su CA (tests verdes, health checks, demo del flujo). Si el CA no se puede verificar, queda ⚠ con nota del bloqueo.
6. **Calidad de constitución no negociable:** overfitting < 5%, split por sujeto, GDPR y criterios de datasets (§6) aplican también al código generado por agentes.

## 8. PRIVACIDAD Y CUMPLIMIENTO (GDPR — OBLIGATORIO)

SentiLife trata datos personales y datos de salud inferidos. Principios innegociables:

1. **Consentimiento explícito:** ningún dato de sensores se recoge sin que la persona monitorizada (o su representante) acepte un modal de consentimiento con lenguaje claro. El consentimiento se registra con fecha y versión de texto, y es revocable.
2. **Minimización:** solo se recogen los campos necesarios para predecir (edad, sexo, peso, altura, telemetría). Nada de identificadores superfluos.
3. **Seudonimización:** la telemetría en InfluxDB se asocia a un identificador técnico, no a datos identificativos directos.
4. **Derecho de supresión:** el sistema debe poder eliminar los datos de una persona a petición.
5. **No es un dispositivo médico:** SentiLife es una herramienta de apoyo; no diagnostica ni sustituye criterio clínico. Debe indicarse en la app.
