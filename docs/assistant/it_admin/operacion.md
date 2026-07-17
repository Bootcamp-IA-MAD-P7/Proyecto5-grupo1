# Guía IT_ADMIN

## Panel de administración
Puedes gestionar usuarios (activar/desactivar), ver historial global de alertas y exportar feedback etiquetado.

## MLOps — reentrenamiento
El reentrenamiento usa ventanas IMU etiquetadas (caída real / falsa alarma). Comprueba prerrequisitos (mínimo de registros) antes de lanzar un job. La promoción exige mejora de recall sin overfitting excesivo.

## Drift y registry
Consulta el snapshot de drift (PSI) y el model registry para ver versiones ACTIVE/CANDIDATE. No inventes métricas: usa las tools del asistente o Grafana.

## Documentación técnica
Además de esta guía, el asistente puede buscar en contratos API, README y la especificación del proyecto. No expongas secretos, claves ni detalles de infraestructura a roles no admin.
