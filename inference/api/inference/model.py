"""Trained model loader and inference wrapper for the SentiLife fall detector.

Loads the ACTIVE model from ``ml/registry/registry.json`` (SL-54 / T4.3).
Supports hot-reload via ``/model/reload`` without restarting the service.
"""

from __future__ import annotations

import pickle
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import pandas as pd

from api.inference.features import extract_features
from api.inference.registry import ModelRegistry

_registry = ModelRegistry()


@dataclass
class _ModelState:
    pipeline: Any = None
    threshold: float = 0.5
    model_name: str = "unloaded"
    numeric_features: list[str] = field(default_factory=list)
    version: str = "unloaded"
    metrics: dict[str, float] = field(default_factory=dict)
    model_path: Path | None = None
    loaded: bool = False


_state = _ModelState()


def _load_from_registry() -> None:
    """Load (or reload) the ACTIVE model declared in the registry."""
    global _state
    _registry.reload()
    entry = _registry.active_entry()
    model_path = entry.path
    if not model_path.is_absolute():
        model_path = Path.cwd() / model_path

    with open(model_path, "rb") as f:
        payload = pickle.load(f)

    _state = _ModelState(
        pipeline=payload["model"],
        threshold=float(payload["threshold"]),
        model_name=payload.get("model_name", entry.algorithm),
        numeric_features=payload["numeric_features"],
        version=entry.id,
        metrics=entry.metrics,
        model_path=model_path,
        loaded=True,
    )


def ensure_loaded() -> None:
    if not _state.loaded:
        _load_from_registry()


def reload() -> str:
    """Hot-reload ACTIVE model from registry without restarting the service."""
    _load_from_registry()
    return _state.version


def version() -> str:
    ensure_loaded()
    return _state.version


def model_name() -> str:
    ensure_loaded()
    return _state.model_name


def metrics_info() -> dict[str, float]:
    ensure_loaded()
    info = dict(_state.metrics)
    info["threshold"] = _state.threshold
    return info


def list_registry() -> list[dict]:
    _registry.reload()
    return [
        {
            "id": m.id,
            "algorithm": m.algorithm,
            "status": m.status,
            "metrics": m.metrics,
            "trainedAt": m.trained_at,
        }
        for m in _registry.list_models()
    ]


def predict(
    accX: list[float],
    accY: list[float],
    accZ: list[float],
    gyroX: list[float],
    gyroY: list[float],
    gyroZ: list[float],
) -> tuple[bool, float]:
    """Run inference on a single sensor window.

    Units (must match ``contracts/window_contract.json``):
    - accX/Y/Z: m/s²
    - gyroX/Y/Z: deg/s (Flutter must convert from rad/s)

    Returns (fall_detected, confidence) where confidence is raw probability.
    """
    ensure_loaded()

    feat = extract_features(accX, accY, accZ, gyroX, gyroY, gyroZ)
    row = pd.DataFrame([{col: feat[col] for col in _state.numeric_features}])

    prob: float = float(_state.pipeline.predict_proba(row)[0, 1])
    fall_detected = prob >= _state.threshold
    return fall_detected, round(prob, 4)
