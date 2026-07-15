# T4.INT — Demo experto MLOps — 14/07/2026

## Objetivo

Demostrar el ciclo MLOps completo **sin stubs**: IT lanza retrain → decisión visible → drift en Grafana → A/B en Prometheus.

Dependencias verificadas: T4.2 ✅ · T4.4 ✅ · T4.5 ✅ · T4.6 ✅ · T4.7 ✅

---

## Ejecución automatizada (API)

Script: `make smoke-expert` (`scripts/smoke-expert-mlops.sh`)

| Paso | Estado | Evidencia |
|---|---|---|
| Stack 6/6 healthy | ✅ | `make verify` |
| Telemetría real (3 ventanas) | ✅ | buffer drift `samples=3` |
| `GET /drift` PSI visible | ✅ | PSI=0.0, `drift_detected=false` |
| IT_ADMIN `POST /admin/retrain` | ✅ | fase inicial DRIFT |
| Pipeline completo | ✅ | DRIFT → TRAINING → COMPLETED (20.3 s) |
| Decisión real (sin stub) | ✅ | **DISCARDED** — recall=0.890 no mejora vs ACTIVE 0.890 |
| Métricas reales | ✅ | overfitting=9.9% · `xgboost-retrain-20260715-001137` |
| Registry | ✅ | 4 modelos en `GET /model/registry` |
| Prometheus A/B | ✅ | `ab_active=3` · `ab_candidate=0` |
| Prometheus drift | ✅ | `feature_drift_psi=0.0` · `feature_drift_samples=3` |

```json
{
  "timestamp": "2026-07-15T00:11:39.286207+00:00",
  "retrain": {
    "decision": "DISCARDED",
    "model_version": "xgboost-retrain-20260715-001137",
    "recall": 0.8903088391906283,
    "overfitting": 0.09912048728605194,
    "elapsed_s": 20.3
  }
}
```

**Nota:** decisión DISCARDED es comportamiento correcto — el retrain real no promueve si recall no supera al ACTIVE. Overfitting 9.9% > 5% también bloquearía promoción (CANDIDATE).

---

## Guion manual (Flutter IT_ADMIN)

Para la presentación del jueves 16:

| # | Acción | Pantalla / URL |
|---|---|---|
| 1 | `make up` + `make smoke-telemetry` (sembrar tráfico) | terminal |
| 2 | Login `admin@sentilife.com` / `Admin1234!` | Flutter |
| 3 | Pestaña **MLOps** (4ª tab) | `ItAdminScreen` |
| 4 | Pulsar **Iniciar reentrenamiento** | polling 2s |
| 5 | Observar fases: DRIFT → TRAINING → EVALUATING → DECIDING | UI i18n es/en |
| 6 | Ver decisión + métricas (recall, overfitting) | tarjeta resultado |
| 7 | Abrir Grafana `:3000` | panel PSI + A/B predictions |
| 8 | (Opcional) mencionar CNN 1D vs XGBoost en informe final | slide técnica |

---

## Grafana

| Panel | URL local | Métrica |
|---|---|---|
| Pipeline | http://localhost:3000 | `ab_testing_predictions_total` |
| Data drift PSI | http://localhost:3000 | `feature_drift_psi` gauge + timeseries |
| Alerta drift | provisioning | `sentilife-drift-psi` > 0.2 |

Credenciales: `admin` / `admin`

---

## Fix infra aplicado en esta sesión

El contenedor `api` fallaba al importar `retrain_feedback` por `window_contract.json` no montado en Docker:

- `docker-compose.yml`: volumen `./contracts:/contracts:ro`
- `window_contract.py`: fallback `/contracts/window_contract.json`

---

## Nivel Experto

**T4.INT ✅** — demo ejecutada 14/07/2026 (local, sin stubs).

Pendiente entrega: **T4.8** presentaciones jue 16.
