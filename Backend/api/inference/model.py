"""Trained model loader and inference wrapper for the SentiLife fall detector.

Loads ``ml/model.pkl`` at application startup (lazy on first call).
Exposes a single ``predict()`` function used by the ``/predict`` endpoint.
"""

from __future__ import annotations

import os
import pickle
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

from api.inference.features import extract_features

_MODEL_PATH = Path(os.getenv("MODEL_PATH", "ml/model.pkl"))

_TRAINED_AT = "2026-07-12"
_MODEL_SCHEMA_VERSION = "xgboost-v1.0.0"


@dataclass
class _ModelState:
    pipeline: Any = None
    threshold: float = 0.5
    model_name: str = "unloaded"
    numeric_features: list[str] = field(default_factory=list)
    version: str = _MODEL_SCHEMA_VERSION
    loaded: bool = False


_state = _ModelState()


def _load() -> None:
    """Load (or reload) the model from disk."""
    global _state
    with open(_MODEL_PATH, "rb") as f:
        payload = pickle.load(f)
    _state = _ModelState(
        pipeline=payload["model"],
        threshold=float(payload["threshold"]),
        model_name=payload["model_name"],
        numeric_features=payload["numeric_features"],
        version=_MODEL_SCHEMA_VERSION,
        loaded=True,
    )


def ensure_loaded() -> None:
    if not _state.loaded:
        _load()


def reload() -> str:
    """Hot-reload the model from disk without restarting the service."""
    _load()
    return _state.version


def version() -> str:
    ensure_loaded()
    return _state.version


def model_name() -> str:
    ensure_loaded()
    return _state.model_name


def metrics_info() -> dict[str, float]:
    return {
        "pr_auc_test": 0.901,
        "f1_fall_test": 0.814,
        "recall_fall_test": 0.832,
        "pr_auc_loso": 0.925,
        "threshold": _state.threshold,
    }


def predict(
    accX: list[float],
    accY: list[float],
    accZ: list[float],
    gyroX: list[float],
    gyroY: list[float],
    gyroZ: list[float],
) -> tuple[bool, float]:
    """Run inference on a single sensor window.

    Units (must match the training contract in ``contracts/window_contract.json``):
    - accX/Y/Z: m/s² (gravity component preserved, no high-pass filter)
    - gyroX/Y/Z: **deg/s** — Flutter sensors_plus reports rad/s; the Flutter
      side must multiply by (180/π) before sending windows.

    Sensor orientation: SisFall was recorded with the sensor on the waist,
    Y-axis aligned with gravity. In still standing the training data shows
    ``accY_mean ≈ -8.5 m/s²``. The app must mount the sensor in a compatible
    orientation or re-train with the real device orientation (T4.4).

    Returns (fall_detected, confidence) where confidence is the raw
    probability output of the model (not thresholded).
    """
    ensure_loaded()

    feat = extract_features(accX, accY, accZ, gyroX, gyroY, gyroZ)
    row = pd.DataFrame([{col: feat[col] for col in _state.numeric_features}])

    prob: float = float(_state.pipeline.predict_proba(row)[0, 1])
    fall_detected = prob >= _state.threshold
    return fall_detected, round(prob, 4)
