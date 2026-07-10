"""
SentiLife Inference Service — FastAPI.

Pure ML inference. No business logic, no auth, no database.
Called only by the Java backend (internal network).

Endpoints:
  GET  /health       — liveness check
  POST /predict      — classify a telemetry window
  GET  /metrics      — Prometheus metrics
  GET  /model/info   — current model metadata
  POST /model/reload — hot-reload model from disk without restart
"""

from __future__ import annotations

import os
import pickle
import time
import threading
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel, Field

# ── App setup ────────────────────────────────────────────────────────────────

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

# ── Configuration ────────────────────────────────────────────────────────────

MODEL_PATH = os.environ.get("MODEL_PATH", "ml/model.pkl")
MODEL_VERSION = os.environ.get("MODEL_VERSION", "unknown")

# ── Model state (thread-safe) ────────────────────────────────────────────────

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

    return True


# ── Prometheus metrics (simple counters, no extra dependency) ─────────────────

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


# ── Request/Response schemas ─────────────────────────────────────────────────

class WindowFeatures(BaseModel):
    """Features of a single telemetry window, sent by Java backend."""
    features: dict = Field(
        ...,
        description="Dictionary of feature_name -> value. Must match model's expected features.",
    )


class PredictionResponse(BaseModel):
    prediction: str = Field(..., description="'FALL' or 'ADL'")
    confidence: float = Field(..., description="Probability of the predicted class")
    model_name: str
    model_version: str
    threshold: float


class ModelInfoResponse(BaseModel):
    model_name: str
    version: str
    threshold: float
    features_count: int
    numeric_features: list[str]
    categorical_features: list[str]
    loaded_at: Optional[str]
    file_path: str


# ── Startup ──────────────────────────────────────────────────────────────────

@app.on_event("startup")
def startup_load_model():
    loaded = _load_model(MODEL_PATH)
    if loaded:
        print(f"[inference] Model loaded: {_model_state['model_name']} from {MODEL_PATH}")
    else:
        print(f"[inference] WARNING: No model found at {MODEL_PATH}. /predict will return 503 until a model is loaded.")


# ── Endpoints ────────────────────────────────────────────────────────────────

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


@app.post("/predict", response_model=PredictionResponse)
def predict(window: WindowFeatures):
    """Classify a telemetry window as FALL or ADL."""
    with _model_lock:
        model = _model_state["model"]
        threshold = _model_state["threshold"]
        numeric_features = _model_state["numeric_features"]
        model_name = _model_state["model_name"]
        version = _model_state["version"]

    if model is None:
        _metrics["prediction_errors"] += 1
        raise HTTPException(
            status_code=503,
            detail="No model loaded. Call POST /model/reload or set MODEL_PATH.",
        )

    start = time.perf_counter()

    try:
        # Build DataFrame with expected feature order
        feature_values = {}
        for feat in numeric_features:
            if feat not in window.features:
                raise HTTPException(
                    status_code=422,
                    detail=f"Missing required feature: '{feat}'. Expected features: {numeric_features}",
                )
            feature_values[feat] = [window.features[feat]]

        df = pd.DataFrame(feature_values)

        # Get probability of fall (class 1)
        proba = model.predict_proba(df)[0]
        fall_prob = float(proba[1])
        is_fall = fall_prob >= threshold

        prediction = "FALL" if is_fall else "ADL"
        confidence = fall_prob if is_fall else (1.0 - fall_prob)

    except HTTPException:
        raise
    except Exception as e:
        _metrics["prediction_errors"] += 1
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")

    elapsed = time.perf_counter() - start
    _record_latency(elapsed)
    _metrics["predictions_total"] += 1
    if is_fall:
        _metrics["predictions_fall"] += 1
    else:
        _metrics["predictions_no_fall"] += 1

    return PredictionResponse(
        prediction=prediction,
        confidence=round(confidence, 4),
        model_name=model_name,
        model_version=version,
        threshold=threshold,
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
    """Hot-reload model from disk. Optionally provide a new path."""
    target = path or _model_state["file_path"]
    loaded = _load_model(target)
    if not loaded:
        raise HTTPException(
            status_code=404,
            detail=f"Model file not found: {target}",
        )
    _metrics["model_reloads"] += 1
    return {
        "status": "reloaded",
        "model_name": _model_state["model_name"],
        "loaded_at": _model_state["loaded_at"],
        "file_path": _model_state["file_path"],
    }


@app.get("/metrics", response_class=PlainTextResponse)
def metrics():
    """Prometheus-compatible metrics endpoint."""
    lines = []

    # Counters
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

    # Histogram — prediction latency
    lines.append("# HELP prediction_latency_seconds Prediction latency")
    lines.append("# TYPE prediction_latency_seconds histogram")
    cumulative = 0
    for i, bound in enumerate(_latency_buckets):
        cumulative += _latency_bucket_counts[i]
        lines.append(f'prediction_latency_seconds_bucket{{le="{bound}"}} {cumulative}')
    lines.append(f'prediction_latency_seconds_bucket{{le="+Inf"}} {_metrics["prediction_latency_count"]}')
    lines.append(f'prediction_latency_seconds_sum {_metrics["prediction_latency_sum"]:.6f}')
    lines.append(f'prediction_latency_seconds_count {_metrics["prediction_latency_count"]}')

    return "\n".join(lines) + "\n"


# ── Run standalone (dev) ─────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("api.main:app", host="0.0.0.0", port=8000, reload=True)
