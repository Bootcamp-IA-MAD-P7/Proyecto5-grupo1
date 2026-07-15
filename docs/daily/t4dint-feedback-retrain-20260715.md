# T4d.INT — E2E feedback → retrain (15/07/2026)

## Objetivo

Verificar que el feedback de producción en Postgres llega al job de retrain vía `POST /train` con `feedback_rows` y que `augmented_windows >= 1`.

## Precondiciones

- Stack local: `docker compose up` (6/6 healthy tras rebuild backend + api)
- Código: T4e.1, T4d.1–T4d.4 aplicados

## Ejecución

```bash
make smoke-mvp    # PATCH feedback TRUE_FALL → export IT
make smoke-expert # POST /admin/retrain → POST /train con body
```

## Resultados

| Check | Resultado | Evidencia |
|---|---|---|
| smoke-mvp | PASS | `exportRowCount: 3`, `exportHasLabeledSample: true` |
| smoke-expert | PASS | Retrain `DISCARDED` recall=0.832, 26.3s |
| `feedback.source` | `http_payload` | `retrain_metrics.json` |
| `augmented_windows` | **3** (≥ 1) | `retrain_metrics.json` §feedback |
| `total_records` | 3 | Mismo job |

## Veredicto

**T4d.INT PASS** — RF-33 cumple: retrain consume feedback real de Postgres sin CSV manual.
