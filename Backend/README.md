# Backend — Fall-Sentinel

API REST (FastAPI), pipeline de ML y notebooks de Kaggle para clasificación de telemetría (Caída vs. ADL).

## Estructura

```
Backend/
├── api/          # Rutas FastAPI, schemas, servicios
├── ml/           # Entrenamiento, inferencia, artefactos del modelo
├── notebooks/    # EDA y experimentos Kaggle (.ipynb)
├── data/
│   ├── raw/      # Dataset original (no commitear archivos grandes)
│   └── processed/ # Datos preprocesados
└── tests/        # Tests unitarios del backend
```

## Dataset candidato

**Real-Time Patient Fall Detection Data** (Kaggle) — pendiente de validación y descarga.

Los notebooks de Kaggle deben vivir en `notebooks/` y referenciar datos en `data/raw/` con rutas relativas.

## Próximos pasos

1. Descargar y documentar el dataset en `data/raw/`
2. EDA en `notebooks/`
3. Entrenar modelo en `ml/`
4. Exponer predicción vía FastAPI en `api/`
