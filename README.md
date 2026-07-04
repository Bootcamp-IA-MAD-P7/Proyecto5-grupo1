# Fall Detector AI

Aplicación móvil desarrollada como parte del **Proyecto 5 - Machine Learning Classification** del Bootcamp de Inteligencia Artificial de **Factoría F5 Madrid**.

El objetivo del proyecto es desarrollar una solución basada en Inteligencia Artificial capaz de estimar el riesgo de caídas en personas mediante el análisis de datos biométricos y de sensores, proporcionando una herramienta de apoyo para profesionales sanitarios, cuidadores y centros asistenciales.

---

## Estado del proyecto

🚧 **En desarrollo (Sprint 0 - Discovery).**

Actualmente el repositorio incluye un prototipo funcional desarrollado en Flutter que utiliza datos simulados para validar la experiencia de usuario y la arquitectura de la aplicación.

En las siguientes iteraciones se integrará un modelo de Machine Learning entrenado con un dataset real, junto con los servicios necesarios para realizar predicciones y gestionar futuras funcionalidades como alertas y seguimiento de eventos.

---

## Funcionalidades actuales

- Simulación de datos de sensores.
- Visualización de variables biométricas.
- Análisis manual de una lectura.
- Simulación de detección de caídas.
- Pantalla de resultados con nivel de confianza.

---

## Funcionalidades previstas

- Integración del modelo de clasificación.
- Predicción del riesgo de caída en tiempo real.
- Comunicación mediante API.
- Gestión de alertas.
- Registro histórico de predicciones.
- Evolución hacia una aplicación móvil de uso sanitario.

---

## Tecnologías

- Flutter
- Dart
- Python
- Scikit-Learn
- Git
- GitHub
- Confluence
- Jira
- Material 3

---

## Estructura del proyecto

```text
.
├── android/
├── ios/
├── lib/
├── docs/
├── daily/
├── web/
├── README.md
└── pubspec.yaml
```

---

## Cómo ejecutar

Clonar el repositorio:

```bash
git clone <repository-url>
```

Entrar en el proyecto:

```bash
cd Proyecto5-grupo1
```

Instalar dependencias:

```bash
flutter pub get
```

Ejecutar la aplicación:

```bash
flutter run
```

Para ejecutar en un dispositivo o emulador concreto:

```bash
flutter devices
flutter run -d <device_id>
```

---

## Documentación

La documentación funcional y técnica del proyecto evoluciona junto con el desarrollo.

Los principales documentos disponibles en este repositorio son:

- `docs/SDD.md`
- `docs/AGENTS.md`

La documentación completa de análisis, planificación y gestión del proyecto se mantiene en **Confluence**.

---

## Flujo de trabajo

El equipo utiliza una estrategia basada en ramas de Git y revisión mediante Pull Requests.

Principales ramas:

- `main`
- `feature/*`
- `fix/*`
- `docs/*`

Todo cambio debe ser revisado antes de integrarse en la rama principal.

---

## Equipo

Proyecto desarrollado por el **Grupo 1** del **Proyecto 5 (Clasificación)** del Bootcamp de Inteligencia Artificial de **Factoría F5 Madrid**.

---

## Licencia

Proyecto desarrollado con fines exclusivamente académicos como parte del programa formativo del Bootcamp de Inteligencia Artificial de Factoría F5 Madrid.