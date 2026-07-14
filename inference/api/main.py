"""
SentiLife Inference Service — FastAPI.

Pure ML inference. No business logic, no auth, no database.
Called only by the Java backend (internal network).

Endpoints:
  GET  /health           — liveness check
  POST /predict          — classify a telemetry window
  GET  /metrics          — Prometheus metrics
  GET  /model/info       — current model metadata
  POST /model/reload     — hot-reload model from disk without restart
  GET  /model/registry   — list all models in registry (SL-54 / T4.3)
  GET  /drift            — feature drift snapshot (PSI vs SisFall baseline)
  POST /drift/recompute  — recompute drift from recent production windows
  POST /train            — retrain model with SisFall + feedback (T4.4)
"""

from __future__ import annotations

import json
import os
import pickle
import threading
import time
from pathlib import Path
from typing import Optional

import pandas as pd
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel, Field

from api.inference.drift import DriftMonitor
from api.inference.features import extract_features
from ml.training.retrain_feedback import run_retrain

# ── App setup ─────────────────────────────────────────────────────────────────

app = FastAPI(
    title="SentiLife Inference Service",
    description="ML inference for fall detection. Internal service — called by Java backend only.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

# ── Configuration ─────────────────────────────────────────────────────────────

MODEL_PATH = os.environ.get("MODEL_PATH", "ml/models/model.pkl")
MODEL_VERSION = os.environ.get("MODEL_VERSION", "unknown")
REGISTRY_PATH = os.environ.get("MODEL_REGISTRY_PATH", "ml/registry/registry.json")

REQUIRED_SIGNALS = ("accX", "accY", "accZ", "gyroX", "gyroY", "gyroZ")
REQUIRED_SAMPLE_COUNT = 125

_drift_monitor = DriftMonitor()

# ── Model state (thread-safe) ─────────────────────────────────────────────────

_model_lock = threading.Lock()
_model_state: dict = {
    "model": None,
    "model_name": "none",
    "threshold": 0.5,
    "numeric_features": [],
    "categorical_features": [],
    "loaded_at": None,
    "file_path": MODEL_PATH,
    "version": MODEL_VERSION,
}


def _load_model(path: str) -> bool:
    """Load model from pickle file. Returns True on success."""
    resolved = Path(path)
    if not resolved.exists():
        return False

    with open(resolved, "rb") as f:
        payload = pickle.load(f)

    with _model_lock:
        _model_state["model"] = payload["model"]
        _model_state["model_name"] = payload.get("model_name", "unknown")
        _model_state["threshold"] = payload.get("threshold", 0.5)
        _model_state["numeric_features"] = payload.get("numeric_features", [])
        _model_state["categorical_features"] = payload.get("categorical_features", [])
        _model_state["loaded_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        _model_state["file_path"] = str(resolved)

    _sync_drift_features()
    return True


def _sync_drift_features() -> None:
    """Limit drift monitoring to features used by the active model."""
    with _model_lock:
        numeric = _model_state["numeric_features"]
    if not numeric:
        return
    monitored = [f for f in numeric if f in _drift_monitor.baseline_bins]
    if monitored:
        _drift_monitor.feature_names = monitored[:40]


def _load_active_from_registry() -> bool:
    """Try to load the ACTIVE model declared in registry.json."""
    reg = Path(REGISTRY_PATH)
    if not reg.exists():
        return False
    try:
        data = json.loads(reg.read_text(encoding="utf-8"))
        active_id = data.get("active")
        for entry in data.get("models", []):
            if entry.get("id") == active_id:
                return _load_model(entry["path"])
    except Exception:
        pass
    return False


# ── Prometheus metrics ────────────────────────────────────────────────────────

_metrics = {
    "predictions_total": 0,
    "predictions_fall": 0,
    "predictions_no_fall": 0,
    "prediction_errors": 0,
    "model_reloads": 0,
    "prediction_latency_sum": 0.0,
    "prediction_latency_count": 0,
}
_latency_buckets = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
_latency_bucket_counts = [0] * len(_latency_buckets)


def _record_latency(seconds: float):
    _metrics["prediction_latency_sum"] += seconds
    _metrics["prediction_latency_count"] += 1
    for i, bound in enumerate(_latency_buckets):
        if seconds <= bound:
            _latency_bucket_counts[i] += 1


# ── Request/Response schemas (spec §6.8) ─────────────────────────────────────


class PredictRequest(BaseModel):
    """Telemetry window payload sent by Java InferenceClient — spec §6.8."""
    windowId: str
    monitoredId: str
    sampleRateHz: int = Field(..., ge=1)
    samples: dict[str, list[float]] = Field(
        ...,
        description="accX/Y/Z (m/s²) and gyroX/Y/Z (deg/s), 125 samples each.",
    )
    subjectFeatures: dict = Field(default_factory=dict)


class PredictionResponse(BaseModel):
    fallDetected: bool
    confidence: float = Field(..., description="Probability of the predicted class (0–1)")
    modelVersion: str
    latencyMs: int


class ModelInfoResponse(BaseModel):
    model_name: str
    version: str
    threshold: float
    features_count: int
    numeric_features: list[str]
    categorical_features: list[str]
    loaded_at: Optional[str]
    file_path: str


class RegistryModel(BaseModel):
    id: str
    algorithm: str
    status: str
    metrics: dict
    trainedAt: Optional[str] = None


class RegistryResponse(BaseModel):
    active: str
    models: list[RegistryModel]


class TrainResponse(BaseModel):
    version: str
    algorithm: str
    recall: float
    precision: float
    f1: float
    overfitting: float
    artifact_uri: str
    metrics: dict


# ── Startup ───────────────────────────────────────────────────────────────────

@app.on_event("startup")
def startup_load_model():
    # Try registry first (SL-54); fall back to MODEL_PATH env var
    loaded = _load_active_from_registry() or _load_model(MODEL_PATH)
    if loaded:
        _sync_drift_features()
        print(f"[inference] Model loaded: {_model_state['model_name']} from {_model_state['file_path']}")
    else:
        print(f"[inference] WARNING: No model found. /predict will return 503 until a model is loaded.")


# ── Endpoints ─────────────────────────────────────────────────────────────────

@app.get("/")
def root():
    return {"status": "ok", "service": "SentiLife Inference Service"}


@app.get("/health")
def health():
    model_loaded = _model_state["model"] is not None
    return {
        "status": "healthy",
        "model_loaded": model_loaded,
        "model_name": _model_state["model_name"],
        "version": _model_state["version"],
    }


def _validate_samples(samples: dict[str, list[float]]) -> tuple[list[float], ...]:
    """Ensure all required signals are present with exactly 125 samples."""
    missing = [s for s in REQUIRED_SIGNALS if s not in samples]
    if missing:
        raise HTTPException(
            status_code=422,
            detail=f"Missing required signals: {missing}",
        )
    lengths = {s: len(samples[s]) for s in REQUIRED_SIGNALS}
    bad = [s for s, n in lengths.items() if n != REQUIRED_SAMPLE_COUNT]
    if bad:
        raise HTTPException(
            status_code=422,
            detail=f"Each signal must have {REQUIRED_SAMPLE_COUNT} samples; invalid: {bad}",
        )
    return tuple(samples[s] for s in REQUIRED_SIGNALS)


@app.post("/predict", response_model=PredictionResponse)
def predict(window: PredictRequest):
    """Classify a telemetry window — spec §6.8 (samples in, fallDetected out)."""
    with _model_lock:
        model = _model_state["model"]
        threshold = _model_state["threshold"]
        numeric_features = _model_state["numeric_features"]
        version = _model_state["version"]

    if model is None:
        _metrics["prediction_errors"] += 1
        raise HTTPException(
            status_code=503,
            detail="No model loaded. Call POST /model/reload or set MODEL_PATH.",
        )

    start = time.perf_counter()

    try:
        accX, accY, accZ, gyroX, gyroY, gyroZ = _validate_samples(window.samples)
        feat = extract_features(accX, accY, accZ, gyroX, gyroY, gyroZ)

        feature_values = {}
        for feat_name in numeric_features:
            if feat_name not in feat:
                raise HTTPException(
                    status_code=422,
                    detail=f"Missing required feature: '{feat_name}'.",
                )
            feature_values[feat_name] = [feat[feat_name]]

        df = pd.DataFrame(feature_values)
        proba = model.predict_proba(df)[0]
        fall_prob = float(proba[1])
        is_fall = fall_prob >= threshold
        confidence = fall_prob if is_fall else (1.0 - fall_prob)
        _drift_monitor.record(feat)

    except HTTPException:
        raise
    except Exception as e:
        _metrics["prediction_errors"] += 1
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}") from e

    elapsed = time.perf_counter() - start
    _record_latency(elapsed)
    _metrics["predictions_total"] += 1
    if is_fall:
        _metrics["predictions_fall"] += 1
    else:
        _metrics["predictions_no_fall"] += 1

    return PredictionResponse(
        fallDetected=is_fall,
        confidence=round(confidence, 4),
        modelVersion=version,
        latencyMs=int(elapsed * 1000),
    )


@app.get("/model/info", response_model=ModelInfoResponse)
def model_info():
    """Return metadata about the currently loaded model."""
    with _model_lock:
        return ModelInfoResponse(
            model_name=_model_state["model_name"],
            version=_model_state["version"],
            threshold=_model_state["threshold"],
            features_count=len(_model_state["numeric_features"]),
            numeric_features=_model_state["numeric_features"],
            categorical_features=_model_state["categorical_features"],
            loaded_at=_model_state["loaded_at"],
            file_path=_model_state["file_path"],
        )


@app.post("/model/reload")
def model_reload(path: Optional[str] = None):
    """Hot-reload model from disk. With no path, reloads ACTIVE from registry."""
    if path:
        loaded = _load_model(path)
    else:
        loaded = _load_active_from_registry() or _load_model(MODEL_PATH)

    if not loaded:
        raise HTTPException(
            status_code=404,
            detail=f"Model file not found: {path or MODEL_PATH}",
        )
    _metrics["model_reloads"] += 1
    _sync_drift_features()
    return {
        "status": "reloaded",
        "model_name": _model_state["model_name"],
        "loaded_at": _model_state["loaded_at"],
        "file_path": _model_state["file_path"],
    }


@app.get("/model/registry", response_model=RegistryResponse)
def model_registry():
    """List all model versions from the registry (SL-54 / T4.3)."""
    reg = Path(REGISTRY_PATH)
    if not reg.exists():
        raise HTTPException(status_code=404, detail=f"Registry not found: {REGISTRY_PATH}")
    try:
        data = json.loads(reg.read_text(encoding="utf-8"))
        return RegistryResponse(
            active=data.get("active", ""),
            models=[RegistryModel(**m) for m in data.get("models", [])],
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Registry read error: {exc}") from exc


@app.get("/drift")
def drift_status():
    """Current feature drift snapshot (PSI vs SisFall training baseline)."""
    return _drift_monitor.snapshot()


@app.post("/drift/recompute")
def drift_recompute():
    """Recompute PSI from recent production windows (T4.7 / retrain DRIFT phase)."""
    result = _drift_monitor.recompute()
    return result


@app.post("/train", response_model=TrainResponse)
def train_model(skip_feature_build: bool = True):
    """Retrain XGBoost with SisFall + feedback data (T4.4 / ML-19)."""
    try:
        result = run_retrain(skip_feature_build=skip_feature_build)
        return TrainResponse(**result)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Training failed: {exc}") from exc


@app.get("/metrics", response_class=PlainTextResponse)
def metrics():
    """Prometheus-compatible metrics endpoint."""
    drift = _drift_monitor.snapshot()
    lines = []

    lines.append("# HELP predictions_total Total predictions served")
    lines.append("# TYPE predictions_total counter")
    lines.append(f'predictions_total {_metrics["predictions_total"]}')

    lines.append("# HELP predictions_fall Total fall predictions")
    lines.append("# TYPE predictions_fall counter")
    lines.append(f'predictions_fall {_metrics["predictions_fall"]}')

    lines.append("# HELP predictions_no_fall Total ADL predictions")
    lines.append("# TYPE predictions_no_fall counter")
    lines.append(f'predictions_no_fall {_metrics["predictions_no_fall"]}')

    lines.append("# HELP prediction_errors Total prediction errors")
    lines.append("# TYPE prediction_errors counter")
    lines.append(f'prediction_errors {_metrics["prediction_errors"]}')

    lines.append("# HELP model_reloads Total model reloads")
    lines.append("# TYPE model_reloads counter")
    lines.append(f'model_reloads {_metrics["model_reloads"]}')

    lines.append("# HELP prediction_latency_seconds Prediction latency")
    lines.append("# TYPE prediction_latency_seconds histogram")
    cumulative = 0
    for i, bound in enumerate(_latency_buckets):
        cumulative += _latency_bucket_counts[i]
        lines.append(f'prediction_latency_seconds_bucket{{le="{bound}"}} {cumulative}')
    lines.append(f'prediction_latency_seconds_bucket{{le="+Inf"}} {_metrics["prediction_latency_count"]}')
    lines.append(f'prediction_latency_seconds_sum {_metrics["prediction_latency_sum"]:.6f}')
    lines.append(f'prediction_latency_seconds_count {_metrics["prediction_latency_count"]}')

    lines.append("# HELP feature_drift_psi Mean PSI of input features vs training baseline")
    lines.append("# TYPE feature_drift_psi gauge")
    lines.append(f'feature_drift_psi {drift["psi"]}')

    lines.append("# HELP feature_drift_detected 1 if PSI exceeds threshold")
    lines.append("# TYPE feature_drift_detected gauge")
    lines.append(f'feature_drift_detected {1 if drift["drift_detected"] else 0}')

    lines.append("# HELP feature_drift_samples Recent windows in drift buffer")
    lines.append("# TYPE feature_drift_samples gauge")
    lines.append(f'feature_drift_samples {drift["samples"]}')

    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("api.main:app", host="0.0.0.0", port=8000, reload=True)
