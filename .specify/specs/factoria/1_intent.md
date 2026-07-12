# 1. Intent — SentiLife

> **Metodología SDD:** este es el primero de los cuatro documentos fundamentales (`1_intent.md` → `2_spec.md` → `3_plan.md` → `4_task.md`). Define el *qué* y el *por qué*; el *cómo* vive en los documentos siguientes. Gobernado por `.specify/memory/constitucion_factoria.md`.

## 1. Propósito del documento

Este documento define la visión, el propósito y la intención funcional de **SentiLife** (anteriormente *Fall-Sentinel*).

Su objetivo es establecer una comprensión compartida del producto antes de comenzar la definición detallada de requisitos (`2_spec.md`), el diseño técnico (`3_plan.md`) y la planificación del desarrollo (`4_task.md`).

Responde a cuatro preguntas fundamentales:

- ¿Qué estamos construyendo?
- ¿Qué problema queremos resolver?
- ¿Quién utilizará el producto?
- ¿Qué debe ofrecer el Producto Mínimo Viable (MVP)?

---

## 2. Visión del producto

**SentiLife** es una plataforma de monitorización y mejora de la calidad de vida asistida por Inteligencia Artificial.

El objetivo del proyecto ha evolucionado: ya no se limita a predecir caídas en personas mayores, sino que aprovecha **toda la data disponible** en los datasets científicos actuales (telemetría IMU de actividades de la vida diaria, y señales de contexto como frecuencia cardíaca, temperatura o luz ambiental) para construir un software que permita **monitorizar y mejorar la calidad de vida** de una persona vulnerable, con un alcance bien definido por fases.

El **núcleo del MVP** sigue siendo la capacidad más crítica y de mayor valor: la **detección de caídas en tiempo real**, donde la predicción en **segundos es fundamental**. Alrededor de ese núcleo, la plataforma se diseña para crecer: cada sensor adicional que la app pueda recoger (frecuencia cardíaca, temperatura, patrones de actividad) alimenta futuras capacidades de monitorización de bienestar sin rediseñar la arquitectura.

La solución integra:

- Una **app móvil Flutter** que recoge la telemetría de los sensores del dispositivo y presenta la información a tres perfiles de usuario.
- Un **backend de negocio en Java (Spring Boot)** que expone las APIs REST, gestiona usuarios, roles (JWT), consentimientos y alertas.
- Un **servicio de inferencia en Python (FastAPI)** que sirve el modelo de Machine Learning entrenado con datasets científicos.
- Una infraestructura de nivel profesional: **RabbitMQ** para eventos, **InfluxDB** para telemetría en tiempo real, **PostgreSQL** para datos de negocio, y **Prometheus + Grafana** para observabilidad.

---

## 3. Problema de negocio

Las caídas representan una de las principales causas de lesiones, pérdida de autonomía e ingresos hospitalarios entre personas mayores y otros colectivos vulnerables. Además del impacto físico, generan un coste económico, social y asistencial elevado para las personas afectadas, sus familias y los sistemas de salud.

La mayoría de las soluciones existentes:

1. **Actúan tarde:** detectan la caída con demora o requieren que la persona pulse un botón, cuando cada segundo cuenta.
2. **Ven poco:** se limitan al evento de caída e ignoran el resto de señales (actividad diaria, constantes, entorno) que permiten entender y mejorar la calidad de vida de la persona.
3. **Aíslan al cuidador:** la persona que cuida no dispone de una vista clara del estado y la evolución de la persona monitorizada.

SentiLife aborda los tres problemas: detección de caídas en tiempo real como capacidad núcleo, arquitectura de datos preparada para incorporar cualquier señal adicional de bienestar, y un perfil dedicado para el cuidador.

---

## 4. Objetivo del producto

Desarrollar un MVP capaz de:

1. **Detectar caídas en tiempo real** a partir de la telemetría de sensores del móvil (acelerómetro, giroscopio), con predicción servida por IA en segundos.
2. **Notificar** al cuidador cuando se detecta una caída.
3. **Gestionar tres perfiles de usuario** con autenticación y roles (JWT).
4. **Recoger el consentimiento explícito** de la persona monitorizada antes de capturar cualquier dato (GDPR).
5. **Almacenar telemetría y predicciones** para historial, auditoría y futuros reentrenamientos del modelo.

El MVP debe demostrar la viabilidad técnica de integrar: app móvil, backend Java, servicio de inferencia ML en Python, mensajería de eventos, bases de datos relacional y de series temporales, observabilidad y despliegue moderno.

---

## 5. Usuarios del sistema

SentiLife define **tres perfiles** con roles diferenciados:

### 5.1 Persona monitorizada (rol `MONITORED`)

La persona vulnerable que lleva el dispositivo encima. Es el sujeto cuya telemetría se recoge.

Necesidades principales:

- Ser monitorizada de forma pasiva y no intrusiva.
- Entender y controlar qué datos se recogen (modal de consentimiento claro, revocable).
- Ver su propio estado de forma simple (monitorización activa/inactiva, última evaluación).

### 5.2 Cuidador / usuario que monitorea (rol `CAREGIVER`)

Familiar o cuidador responsable del seguimiento de una o varias personas monitorizadas.

Necesidades principales:

- **Registrar a la persona a monitorizar** mediante un formulario con los datos mínimos necesarios para mejorar la predicción (nombre, edad, sexo, peso, altura), sin violar el GDPR: solo datos pertinentes, con consentimiento registrado.
- Ver en tiempo casi real el estado de la persona monitorizada.
- Recibir **alertas inmediatas** cuando se detecta una caída.
- Consultar el historial de eventos y la evolución.

### 5.3 Área IT / administración (rol `IT_ADMIN`)

Perfil técnico interno de la plataforma.

Necesidades principales:

- Consultar el **historial completo** de telemetría, predicciones y feedback.
- Acceder a los **datos reales recogidos** para preparar reentrenamientos del modelo (niveles Medio/Experto del bootcamp).
- Supervisar la salud del sistema (dashboards Grafana, métricas Prometheus).
- Gestionar usuarios y versiones del modelo.

---

## 6. Stakeholders

- Product Owner (Alex).
- Equipo de Desarrollo (Grupo 1: Gabriela, Jose, Josué, Arnaldo).
- Scrum Master (Gabriela).
- Personas monitorizadas y sus cuidadores (usuarios finales).
- Profesionales sanitarios (evolución futura).
- Factoría F5 como cliente académico.

---

## 7. Propuesta de valor

1. **Reacción en segundos:** pipeline de tiempo real (sensores → API → inferencia → alerta) diseñado para latencias mínimas, porque en una caída cada segundo cuenta.
2. **Plataforma, no feature:** la arquitectura de eventos (RabbitMQ) y series temporales (InfluxDB) permite incorporar nuevos sensores y nuevas señales de bienestar sin rediseño. Los datos extra de sensores hacen crecer la app.
3. **Privacidad por diseño:** consentimiento explícito, minimización de datos, seudonimización de la telemetría, derecho de supresión.
4. **Ciclo de vida ML completo:** el área IT dispone de datos reales para reentrenar; el sistema está preparado para evolucionar hacia MLOps (drift, A/B testing, auto-reemplazo).
5. **Basada en evidencia:** modelos entrenados exclusivamente con datasets científicos validados (constitución §6).

---

## 8. Visión funcional del producto

### Persona monitorizada

- Aceptar (o revocar) el consentimiento de recogida de datos mediante un modal claro al primer uso.
- Iniciar/detener la monitorización pasiva de sensores.
- Ver su estado actual y su última evaluación de forma simple.

### Cuidador

- Registrarse y autenticarse en la plataforma.
- Registrar personas a monitorizar mediante formulario (datos mínimos: nombre, edad, sexo, peso, altura).
- Ver el estado en tiempo casi real de las personas bajo su cuidado.
- Recibir alertas de caída con la información del evento.
- Consultar el historial de eventos y confirmar/descartar caídas (feedback que alimenta al modelo).

### Área IT

- Consultar el historial completo de telemetría y predicciones.
- Exportar datos reales etiquetados (con feedback) para reentrenamiento.
- Supervisar dashboards de sistema (Grafana) y métricas del modelo.
- Gestionar usuarios, roles y versiones de modelo.

### Capacidades de la plataforma

- Autenticación y autorización con **JWT y roles**.
- Ingesta de telemetría en tiempo real (InfluxDB) y eventos desacoplados (RabbitMQ).
- Comunicación segura entre app y APIs.
- Observabilidad de extremo a extremo (Prometheus + Grafana).
- Actualización remota de la app (OTA).
- Arquitectura preparada para: wearables, nuevos sensores (temperatura, frecuencia cardíaca), nuevos modelos de IA y aprendizaje continuo.

---

## 9. Funcionalidades principales del MVP

### Detección de caídas en tiempo real (núcleo)

- Captura continua de acelerómetro y giroscopio desde el móvil.
- Envío de ventanas de telemetría al backend y clasificación por IA (Caída vs. ADL).
- Latencia objetivo de extremo a extremo: **< 5 segundos** desde el evento hasta la alerta.

### Gestión de usuarios, roles y consentimiento

- Registro y login con JWT (roles `MONITORED`, `CAREGIVER`, `IT_ADMIN`).
- Formulario de registro de persona monitorizada (datos mínimos para predicción).
- Modal de consentimiento con registro de fecha/versión y revocación.

### Alertas

- Evento de caída publicado en RabbitMQ y entregado al cuidador mediante **notificación push** (Firebase Cloud Messaging), incluso con la app cerrada; la consulta in-app queda como respaldo.
- Cambios de estado del monitoreado (monitorización iniciada/detenida, consentimiento revocado) también notificados al cuidador.
- Registro del evento en historial.

### Historial y feedback

- Historial de eventos y predicciones consultable por cuidador (sus personas) e IT (global).
- Confirmación/descarte de caídas por el cuidador → dato etiquetado para reentrenamiento.

### Observabilidad

- Métricas de API, cola y latencia de inferencia en Prometheus.
- Dashboard base en Grafana.

---

## 10. Alcance del MVP

Incluye:

- App Flutter con los tres perfiles y sus flujos mínimos.
- Backend Java (Spring Boot): auth JWT, roles, usuarios, personas monitorizadas, consentimientos, alertas, historial.
- Servicio de inferencia FastAPI sirviendo el modelo ML (Caída vs. ADL).
- RabbitMQ para eventos de telemetría/predicción/alerta.
- PostgreSQL (negocio) + InfluxDB (telemetría en tiempo real).
- Notificaciones push al cuidador (FCM).
- App multiidioma (mínimo español e inglés).
- Modal de transparencia de datos: el usuario sabe que sus predicciones y feedback se usan para reentrenar el modelo.
- Prometheus + Grafana con dashboard básico.
- Docker Compose de todo el stack (**un solo `docker compose up` levanta toda la infraestructura**; la app se lanza por script); despliegue en la nube; CI/CD.
- Cumplimiento de los niveles Esencial → Avanzado del bootcamp, con base para Experto.

---

## 11. Fuera del alcance (Out of Scope)

Durante el MVP no se contempla:

- Diagnóstico médico ni sustitución de la valoración de profesionales sanitarios.
- Historia clínica del paciente.
- Panel para profesionales sanitarios.
- Integración con wearables físicos (la arquitectura queda preparada; se simula con sensores del móvil).
- Alertas automáticas a servicios de emergencia (112/SMS/llamada).
- Predicción de *riesgo futuro* de caída (score preventivo) — evolución posterior; el MVP detecta el evento.
- Monitorización de bienestar más allá de las señales disponibles en los datasets validados.

---

## 12. Principios del producto

- **Tiempo real primero:** las decisiones técnicas priorizan la latencia del pipeline de detección.
- **Privacidad por diseño:** consentimiento explícito, minimización, seudonimización, supresión (constitución §8).
- **Simplicidad para el usuario final:** la persona monitorizada no necesita conocimientos técnicos.
- **Escalabilidad y modularidad:** eventos desacoplados y servicios independientes; nuevos sensores y modelos se incorporan sin rediseño.
- **Evidencia:** todas las decisiones de ML se apoyan en datos, métricas objetivas y datasets con soporte académico.
- **Apoyo, no diagnóstico:** SentiLife no es un dispositivo médico.

---

## 13. Criterios de éxito

El MVP se considerará satisfactorio cuando:

- Una caída simulada con el móvil genere una alerta en el perfil del cuidador en **menos de 5 segundos**.
- El modelo cumpla las métricas del bootcamp (overfitting < 5%, informe completo de rendimiento).
- Los tres perfiles funcionen con autenticación JWT y permisos correctos.
- Ningún dato se recoja sin consentimiento registrado, y la revocación detenga la recogida.
- El stack completo se levante con Docker Compose y se despliegue en la nube con CI/CD.
- Grafana muestre métricas reales de API e inferencia.
- El área IT pueda exportar datos etiquetados listos para reentrenamiento.

---

## 14. Restricciones

- Tiempo y recursos del Bootcamp de IA de Factoría F5.
- Datasets limitados a fuentes con soporte académico (constitución §6): SisFall activo, MobiAct candidato.
- El modelo ML debe servirse vía FastAPI (requisito del bootcamp).
- El equipo aprende Java/Spring Boot en paralelo: el alcance del backend Java debe ser realista.
- Presupuesto cloud limitado (EC2 compartido).

---

## 15. Supuestos

- Los datasets seleccionados representan adecuadamente el problema de detección de caídas.
- El móvil de la persona monitorizada dispone de acelerómetro y giroscopio y permanece con la persona.
- La integración Flutter ↔ Java ↔ Python ↔ colas es técnicamente viable en el tiempo disponible.
- RabbitMQ e InfluxDB son discutibles como alcance: se incluyen para elevar el perfil profesional del proyecto, con fallback documentado en `3_plan.md` si comprometen el MVP.
- El sistema es una herramienta de apoyo, no un dispositivo médico.

---

## 16. Riesgos iniciales

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Sesgo de datasets (caídas simuladas por jóvenes en SisFall) | Modelo poco fiable en mayores | Documentar limitación; MobiAct como complemento; feedback real vía app |
| Complejidad del stack (Java + Python + RabbitMQ + InfluxDB + observabilidad) | No llegar al MVP | Fases incrementales en `3_plan.md`; fallback: HTTP directo sin cola, PostgreSQL sin InfluxDB |
| Curva de aprendizaje Java/Spring Boot | Retrasos en backend | Alcance de negocio mínimo; plantillas y arquetipos; inferencia sigue en Python |
| Latencia extremo a extremo > objetivo | Núcleo del producto falla | Medir desde el día 1 (Prometheus); ventanas de telemetría optimizadas |
| Cambios de alcance durante el bootcamp | Dispersión | SDD como fuente de verdad; cambios pasan por actualizar intent/spec |
| GDPR mal implementado | Bloqueo académico/legal | Constitución §8 como checklist; consentimiento antes que telemetría |

---

## 17. Dependencias

- Flutter (app móvil, sensores del dispositivo).
- Java 21 + Spring Boot (backend de negocio).
- Python + FastAPI (servicio de inferencia).
- Scikit-learn / XGBoost (modelado).
- RabbitMQ (eventos) · InfluxDB (series temporales) · PostgreSQL (negocio).
- Prometheus + Grafana (observabilidad).
- Dataset SisFall (activo) · MobiAct (candidato).
- Docker · GitHub Actions · AWS EC2.

---

## 18. Estado del documento

| Campo | Valor |
|--------|--------|
| Estado | Draft v0.2 |
| Autores | Gabriela Granja (Scrum Master) · Arnaldo Rodrigues (Developer) |
| Revisión técnica | José · Josué |
| Product Owner | Alex |
| Última actualización | 08/07/2026 |

---

## Historial de cambios

| Versión | Fecha | Autores | Descripción |
|---------|--------|----------|-------------|
| 0.1 | 06/07/2026 | Gabriela Granja · Arnaldo Rodrigues | Primera versión del documento de intención (Fall-Sentinel). |
| 0.2 | 08/07/2026 | Equipo Grupo 1 | Renombrado a **SentiLife**. Ampliación de visión (calidad de vida), 3 perfiles de usuario, backend Java, RabbitMQ, InfluxDB, Prometheus/Grafana, GDPR y consentimiento, criterios de éxito de tiempo real. |
| 0.3 | 08/07/2026 | Equipo Grupo 1 | Notificaciones push (FCM), multiidioma, modal de transparencia de datos y premisa de infraestructura con un solo compose. |
