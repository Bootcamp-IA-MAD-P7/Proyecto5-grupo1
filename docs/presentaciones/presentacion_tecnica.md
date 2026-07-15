---
marp: true
theme: default
paginate: true
title: SentiLife — Presentación Técnica
---

# SentiLife — Arquitectura Técnica
## Nivel Experto · MLOps end-to-end

**Factoría F5 Madrid · Grupo 1 · Julio 2026**

---

## Stack

| Capa | Tecnología | Rol |
|---|---|---|
| Frontend | Flutter (Dart) | 3 roles, sensores IMU, i18n es/en |
| Backend | Spring Boot 3 · Java 21 | JWT, negocio, orquestación |
| Inferencia | FastAPI · Python 3.11 | `/predict`, registry, drift, train |
| Datos | PostgreSQL | Usuarios, telemetría, alertas, modelos |
| Eventos | RabbitMQ | `alert.created` → FCM push |
| Observabilidad | Prometheus + Grafana | Latencia, A/B, drift, colas |

**Regla:** Flutter → Java → FastAPI. Nunca directo a ML.

---

## Arquitectura

```text
Flutter ──HTTPS/JWT──► Spring Boot ──HTTP──► FastAPI
                           │                    │
                      PostgreSQL           model.pkl
                           │
                      RabbitMQ ──► FCM Push
                           │
                    Prometheus ──► Grafana
```

6 contenedores: `db` · `rabbitmq` · `backend` · `api` · `prometheus` · `grafana`

---

## Contrato de ventana IMU

| Parámetro | Valor |
|---|---|
| Duración | 2,5 s @ 50 Hz |
| Muestras | 125 × 6 señales |
| Solape | 50% |
| Features | 116 estadísticas |
| Contrato | `contracts/window_contract.json` v1.0.0 |

Pipeline: `SlidingWindowBuilder` (Flutter) ↔ `features.py` (Python) — paridad verificada.

---

## Modelo ML — evolución

| Fase | Modelo | PR-AUC test | Recall | LOSO |
|---|---|---|---|---|
| T1 Baseline | XGBoost | 0.901 | 0.832 | 0.925 |
| T2 Optuna | XGBoost tuned | 0.916 | — | — |
| T2c.5 Móvil | `xgboost-v1.1.0-mobile-aligned` | 0.914 | **0.890** | — |
| T4.2 CNN 1D | experimento | 0.862 | 0.760 | 0.801 |

**Producción:** XGBoost tabular (LOSO gana a CNN +12.4 pp).

---

## Validación por sujeto

- `GroupShuffleSplit` 70/15/15 — **0 sujetos compartidos**
- LOSO: 38 folds leave-one-subject-out
- Overfitting < 5% (gap train→test PR-AUC)
- Sin SMOTE (features estadísticas, no series crudas interpoladas)

Sesgo SisFall documentado: 14 mayores sin ensayos de caída.

---

## Paridad móvil ↔ SisFall (T2c.5)

**Problema:** modelo entrenado en cintura SisFall fallaba en móvil.

**Causa raíz:** `GRAVITY_AXIS` + `PEAK_SHAPE` (informe paridad).

**Solución:** `gravity_align.py` antes de features → reentreno → **0 FP** en ADL replay.

---

## Registry de modelos (T4.3)

```json
// ml/registry/registry.json
{ "version": "xgboost-v1.1.0-mobile-aligned", "status": "ACTIVE", ... }
```

Endpoints FastAPI:
- `GET /model/registry` — listar versiones
- `POST /model/reload` — hot-reload sin restart

Java: `RegistryService.promote()` → HTTP reload.

---

## A/B Testing (T4.6)

```java
// ABTestingService — 80% ACTIVE / 20% CANDIDATE
ab_testing_predictions_total{model_status="ACTIVE"}
ab_testing_predictions_total{model_status="CANDIDATE"}
```

Panel Grafana: distribución de predicciones por versión.

---

## Data Drift (T4.7)

| Componente | Implementación |
|---|---|
| Métrica | PSI medio (40 features) vs baseline SisFall |
| Buffer | 500 ventanas en `/predict` |
| Umbral | 0.2 → `feature_drift_detected=1` |
| Endpoints | `GET /drift` · `POST /drift/recompute` |
| Alerta | `observability/grafana/provisioning/alerting/drift.yml` |

---

## Retrain pipeline (T4.4 + T4.5)

```
IT_ADMIN (Flutter MLOps tab)
    → POST /api/v1/admin/retrain
    → DRIFT (PSI)
    → TRAINING (POST /train)
    → EVALUATING
    → DECIDING (recall ↑ + overfitting ≤ 5%)
    → PROMOTED | CANDIDATE | DISCARDED
```

UI: polling 2s, fases + métricas visibles. Sin stubs.

---

## Seguridad y roles

- JWT con roles: `MONITORED` · `CAREGIVER` · `IT_ADMIN`
- `@PreAuthorize` en `/admin/**`, `/admin/retrain/**`
- Device token SHA-256 en pairing (T2c.11)
- GDPR: `DELETE /monitored-persons/{id}` → 0 filas en 6 tablas

Tests: `ApiSecurityIntegrationTest` 9 escenarios.

---

## CI/CD y tests

| Suite | Resultado |
|---|---|
| `mvn test` | **66/66** |
| `pytest tests/` | **52/52** (4 skipped) |
| `flutter test` | **104/104** |

Smokes: `smoke-telemetry` · `smoke-mvp` · `smoke-qa-ec2` · **`smoke-expert`**

GitHub Actions: build + test + deploy EC2 on `main`.

---

## Demo experto (T4.INT)

```bash
make up && make smoke-expert
```

Verifica sin stubs:
1. Telemetría real → buffer drift
2. IT lanza retrain → decisión con métricas reales
3. Prometheus: A/B + `feature_drift_psi`
4. Grafana: paneles drift + pipeline

Acta: `docs/daily/t4int-expert-demo-20260714.md`

---

## Decisiones de alcance

| Decisión | Motivo |
|---|---|
| MobiAct ✂ CEMP | Factoría = SisFall |
| XGBoost > CNN 1D | LOSO superior, menor coste inferencia |
| InfluxDB → Postgres | ADR-03, telemetría en PostgreSQL |
| 0 mocks en Flutter | Contrato real obligatorio |

---

## Entregables

| Documento | Ruta |
|---|---|
| Informe técnico final | `inference/docs/informe_tecnico_final.md` |
| SDD completo | `.specify/specs/factoria/` |
| Presentación negocio | `docs/presentaciones/presentacion_negocio.md` |
| Presentación técnica | `docs/presentaciones/presentacion_tecnica.md` |
| Artefactos ML | `ml/artifacts/*.json` |

---

# Fin
## Repositorio: Proyecto5-grupo1 · rama `dev`
