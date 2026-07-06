# 1. Intent

## 1. Propósito del documento

Este documento define la visión, el propósito y la intención funcional de **Fall-Sentinel**.

Su objetivo es establecer una comprensión compartida del producto antes de comenzar la definición detallada de requisitos, el diseño técnico y la planificación del desarrollo.

Este documento responde a cuatro preguntas fundamentales:

- ¿Qué estamos construyendo?
- ¿Qué problema queremos resolver?
- ¿Quién utilizará el producto?
- ¿Qué debe ofrecer el Producto Mínimo Viable (MVP)?

---

## 2. Visión del producto

Fall-Sentinel es una plataforma de apoyo basada en Inteligencia Artificial diseñada para estimar el riesgo de caída de una persona a partir de información obtenida mediante sensores y variables biométricas.

La solución integra una aplicación móvil desarrollada en Flutter, una API REST implementada con FastAPI y un modelo de Machine Learning entrenado con datasets científicos para ofrecer una evaluación sencilla, rápida y accesible.

La visión a largo plazo es evolucionar hacia una plataforma escalable que contribuya a la prevención de caídas, facilite el seguimiento de personas vulnerables y apoye la toma de decisiones de familiares, cuidadores y profesionales sanitarios.

---

## 3. Problema de negocio

Las caídas representan una de las principales causas de lesiones, pérdida de autonomía e ingresos hospitalarios entre personas mayores y otros colectivos vulnerables.

Además de las consecuencias físicas, las caídas generan un importante impacto económico, social y asistencial tanto para las personas afectadas como para sus familias y los sistemas de salud.

Actualmente la mayoría de las soluciones disponibles actúan una vez producido el accidente. Fall-Sentinel propone un enfoque preventivo mediante el uso de Inteligencia Artificial para estimar el riesgo antes de que ocurra una caída.

---

## 4. Objetivo del producto

Desarrollar un Producto Mínimo Viable capaz de estimar el riesgo de caída utilizando información obtenida mediante sensores, mostrando el resultado de forma clara y comprensible a través de una aplicación móvil.

El MVP deberá demostrar la viabilidad técnica de integrar:

- Aplicación móvil.
- API REST.
- Modelo de Machine Learning.
- Infraestructura moderna de despliegue.

---

## 5. Usuarios del sistema

### Usuario principal — Persona en riesgo de caída

Persona interesada en conocer su nivel de riesgo mediante una aplicación sencilla e intuitiva.

Necesidades principales:

- Evaluar su riesgo de caída.
- Comprender fácilmente el resultado obtenido.
- Recibir información que favorezca la prevención.

---

### Usuario secundario — Familiar o cuidador

Persona responsable del seguimiento o cuidado de una persona vulnerable.

Necesidades principales:

- Conocer el nivel de riesgo del usuario.
- Facilitar el seguimiento de su evolución.
- Disponer de información que apoye la toma de decisiones.

---

### Usuario futuro — Profesional sanitario *(Fuera del alcance del MVP)*

Profesional que podrá utilizar futuras versiones de la plataforma como herramienta complementaria para el seguimiento y evaluación del riesgo de sus pacientes.

---

## 6. Stakeholders

Los principales interesados en el proyecto son:

- Product Owner.
- Equipo de Desarrollo.
- Scrum Master.
- Personas en riesgo de caída.
- Familiares y cuidadores.
- Profesionales sanitarios (evolución futura).
- Factoría F5 como cliente académico.

---

## 7. Propuesta de valor

Fall-Sentinel acerca la Inteligencia Artificial al ámbito de la prevención de caídas mediante una solución accesible, sencilla y basada en evidencia científica.

La plataforma busca facilitar la detección temprana de situaciones de riesgo y apoyar la toma de decisiones preventivas antes de que ocurra una caída.

Su arquitectura modular permitirá evolucionar el producto de forma progresiva incorporando nuevas funcionalidades sin necesidad de rediseños significativos.

---

## 8. Visión funcional del producto

### Persona en riesgo de caída

La aplicación permitirá al usuario:

- Realizar una evaluación del riesgo de caída.
- Obtener una estimación generada mediante Inteligencia Artificial.
- Visualizar el resultado mediante una interfaz sencilla e intuitiva.
- Recibir recomendaciones preventivas basadas en la evaluación realizada.
- Mantener la aplicación actualizada mediante actualizaciones OTA.

---

### Familiar o cuidador

En futuras iteraciones la plataforma permitirá:

- Consultar el nivel de riesgo de la persona supervisada.
- Visualizar el historial de evaluaciones realizadas.
- Hacer seguimiento de la evolución del riesgo.
- Recibir alertas cuando se detecten situaciones de riesgo.
- Gestionar la información básica de las personas bajo su cuidado.

---

### Profesional sanitario *(Evolución futura)*

Las futuras versiones podrán incorporar funcionalidades como:

- Consulta de evaluaciones realizadas por los pacientes.
- Seguimiento de la evolución del riesgo.
- Herramientas de apoyo a la toma de decisiones clínicas.
- Gestión de múltiples pacientes.
- Indicadores y estadísticas de seguimiento.

---

### Capacidades de la plataforma

La arquitectura del sistema permitirá evolucionar el producto incorporando progresivamente funcionalidades como:

- Comunicación segura con la API.
- Actualización remota de versiones (OTA).
- Integración con sensores reales del dispositivo.
- Integración con dispositivos wearables.
- Evolución del modelo de Machine Learning.
- Aprendizaje continuo mediante nuevos datos.
- Arquitectura modular y escalable.

---

## 9. Funcionalidades principales

La primera versión de Fall-Sentinel se concibe como una plataforma modular cuya funcionalidad podrá ampliarse progresivamente. Entre las capacidades previstas se encuentran:

### Evaluación del riesgo de caída

- Analizar información procedente de sensores y variables biométricas.
- Generar una predicción del riesgo mediante Inteligencia Artificial.
- Mostrar el nivel de riesgo de forma comprensible.

### Gestión de usuarios

- Permitir la utilización de la aplicación por personas en riesgo de caída.
- Facilitar futuras funcionalidades para familiares y cuidadores.

### Seguimiento

- Registrar futuras evaluaciones realizadas.
- Consultar la evolución del riesgo a lo largo del tiempo.

### Alertas *(Evolución futura)*

- Notificar a familiares o cuidadores cuando se detecten situaciones de riesgo.
- Configurar diferentes mecanismos de notificación.

### Plataforma

- Comunicación segura con la API REST.
- Actualizaciones OTA.
- Integración futura con sensores reales.
- Integración con dispositivos wearables.
- Arquitectura preparada para incorporar nuevos modelos de IA.

---

## 10. Alcance del MVP

La primera versión del producto incluirá:

- Aplicación móvil desarrollada en Flutter.
- Comunicación con una API REST.
- Evaluación del riesgo de caída mediante Inteligencia Artificial.
- Visualización clara del resultado obtenido.
- Arquitectura preparada para futuras ampliaciones.

---

## 11. Fuera del alcance (Out of Scope)

Durante el desarrollo del MVP no se contempla:

- Diagnóstico médico.
- Sustituir la valoración realizada por profesionales sanitarios.
- Historia clínica del paciente.
- Panel profesional.
- Integración con dispositivos wearables.
- Alertas automáticas a servicios de emergencia.
- Gestión multiusuario.

Estas funcionalidades podrán incorporarse en futuras versiones del producto.

---

## 12. Principios del producto

El desarrollo de Fall-Sentinel se basará en los siguientes principios:

- **Simplicidad:** la aplicación debe poder utilizarse sin conocimientos técnicos.
- **Prevención:** el objetivo es apoyar la identificación temprana del riesgo, no sustituir el criterio clínico.
- **Escalabilidad:** la arquitectura deberá facilitar la incorporación de nuevas funcionalidades.
- **Modularidad:** los componentes deberán permanecer desacoplados para facilitar su mantenimiento y evolución.
- **Evidencia:** las decisiones relacionadas con el modelo de Inteligencia Artificial deberán apoyarse en datos y métricas objetivas.

---

## 13. Criterios de éxito

El MVP se considerará satisfactorio cuando:

- El sistema genere una predicción funcional del riesgo de caída.
- La aplicación móvil se comunique correctamente con la API.
- El usuario reciba un resultado claro e interpretable.
- La solución pueda desplegarse correctamente.
- La arquitectura permita evolucionar el producto sin rediseños importantes.

---

## 14. Restricciones

El proyecto se desarrolla en el contexto del Bootcamp de Inteligencia Artificial de Factoría F5, por lo que presenta restricciones relacionadas con:

- Tiempo disponible.
- Recursos técnicos.
- Disponibilidad de datasets científicos.
- Alcance académico del proyecto.

---

## 15. Supuestos

Durante el desarrollo se asume que:

- Los datasets seleccionados representan adecuadamente el problema estudiado.
- El usuario dispone de un dispositivo móvil compatible.
- La integración entre Frontend, Backend y Machine Learning será técnicamente viable.
- El sistema constituye una herramienta de apoyo y no un dispositivo médico.

---

## 16. Riesgos iniciales

Los principales riesgos identificados son:

- Sesgo de los datasets utilizados para el entrenamiento.
- Integración del modelo de Machine Learning en producción.
- Cambios de alcance durante el desarrollo.
- Limitaciones temporales propias del Bootcamp.

---

## 17. Dependencias

El desarrollo del proyecto depende principalmente de:

- Flutter.
- FastAPI.
- Python.
- Machine Learning.
- Dataset SisFall.
- PostgreSQL.
- Docker.
- AWS EC2.
- GitHub Actions.

---

## 18. Estado del documento

| Campo | Valor |
|--------|--------|
| Estado | Draft v0.1 |
| Autores | Gabriela Granja (Scrum Master) · Arnaldo Rodrigues (Developer) |
| Revisión técnica | José · Josué |
| Product Owner | Alex |
| Última actualización | 06/07/2026 |

---

## Historial de cambios

| Versión | Fecha | Autores | Descripción |
|---------|--------|----------|-------------|
| 0.1 | 06/07/2026 | Gabriela Granja · Arnaldo Rodrigues | Primera versión del documento de intención del producto. Pendiente de revisión técnica y funcional por el equipo de desarrollo. |