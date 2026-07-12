"""Model registry for SentiLife inference service (SL-54 / T4.3)."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any

REGISTRY_PATH = Path(os.getenv("MODEL_REGISTRY_PATH", "ml/registry/registry.json"))


@dataclass
class ModelEntry:
    id: str
    path: Path
    algorithm: str
    status: str  # ACTIVE | CANDIDATE | ARCHIVED
    metrics: dict[str, float]
    trained_at: str | None = None
    optuna_params: dict[str, Any] | None = None

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> ModelEntry:
        return cls(
            id=data["id"],
            path=Path(data["path"]),
            algorithm=data["algorithm"],
            status=data["status"],
            metrics=data.get("metrics", {}),
            trained_at=data.get("trainedAt"),
            optuna_params=data.get("optuna_params"),
        )


class ModelRegistry:
    def __init__(self, registry_path: Path = REGISTRY_PATH) -> None:
        self._path = registry_path
        self._data: dict[str, Any] = {}
        self.reload()

    def reload(self) -> None:
        if not self._path.exists():
            self._data = {
                "active": "xgboost-v1.0.0",
                "models": [
                    {
                        "id": "xgboost-v1.0.0",
                        "path": "ml/model.pkl",
                        "algorithm": "XGBoost",
                        "status": "ACTIVE",
                        "metrics": {},
                        "trainedAt": None,
                    }
                ],
            }
            return
        self._data = json.loads(self._path.read_text(encoding="utf-8"))

    def active_entry(self) -> ModelEntry:
        active_id = self._data.get("active")
        for raw in self._data.get("models", []):
            if raw["id"] == active_id:
                return ModelEntry.from_dict(raw)
        # Fallback al primer modelo ACTIVE o al primero disponible
        for raw in self._data.get("models", []):
            if raw.get("status") == "ACTIVE":
                return ModelEntry.from_dict(raw)
        return ModelEntry.from_dict(self._data["models"][0])

    def list_models(self) -> list[ModelEntry]:
        return [ModelEntry.from_dict(m) for m in self._data.get("models", [])]

    def promote(self, model_id: str) -> ModelEntry:
        """Promueve un CANDIDATE a ACTIVE (para retrain T4.4)."""
        found = None
        for raw in self._data.get("models", []):
            if raw["id"] == model_id:
                found = raw
                break
        if not found:
            raise ValueError(f"Model {model_id} not in registry")

        for raw in self._data.get("models", []):
            if raw["status"] == "ACTIVE":
                raw["status"] = "ARCHIVED"
        found["status"] = "ACTIVE"
        self._data["active"] = model_id
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._path.write_text(json.dumps(self._data, indent=2), encoding="utf-8")
        return ModelEntry.from_dict(found)
