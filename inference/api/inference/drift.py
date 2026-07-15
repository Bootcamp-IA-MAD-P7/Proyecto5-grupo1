"""Feature drift monitoring — PSI vs SisFall training baseline (ML-18 / T4.7)."""

from __future__ import annotations

import json
import threading
from collections import deque
from pathlib import Path

import numpy as np
import pandas as pd

DEFAULT_BASELINE_CSV = Path("data/processed/sisfall/sisfall_windows_features.csv.gz")
BASELINE_ARTIFACT = Path("ml/artifacts/drift_baseline.json")
PSI_THRESHOLD = float(__import__("os").environ.get("DRIFT_PSI_THRESHOLD", "0.2"))
MIN_RECENT_SAMPLES = int(__import__("os").environ.get("DRIFT_MIN_SAMPLES", "30"))
MAX_RECENT = int(__import__("os").environ.get("DRIFT_MAX_RECENT", "500"))
N_BINS = 10
EPS = 1e-6


def _psi(expected: np.ndarray, actual: np.ndarray) -> float:
    """Population Stability Index for two bin proportion vectors."""
    expected = np.clip(expected, EPS, None)
    actual = np.clip(actual, EPS, None)
    expected = expected / expected.sum()
    actual = actual / actual.sum()
    return float(np.sum((actual - expected) * np.log(actual / expected)))


def _histogram_proportions(values: np.ndarray, edges: np.ndarray) -> np.ndarray:
    counts, _ = np.histogram(values, bins=edges)
    total = counts.sum()
    if total == 0:
        return np.full(len(counts), 1.0 / len(counts))
    return counts.astype(float) / total


class DriftMonitor:
    """Compare recent production features against a SisFall training baseline."""

    def __init__(
        self,
        feature_names: list[str] | None = None,
        baseline_csv: Path = DEFAULT_BASELINE_CSV,
        baseline_artifact: Path = BASELINE_ARTIFACT,
        psi_threshold: float = PSI_THRESHOLD,
        max_recent: int = MAX_RECENT,
    ) -> None:
        self._lock = threading.Lock()
        self.psi_threshold = psi_threshold
        self.max_recent = max_recent
        self.recent: deque[dict[str, float]] = deque(maxlen=max_recent)
        self.feature_names: list[str] = []
        self.baseline_bins: dict[str, list[float]] = {}
        self.baseline_expected: dict[str, list[float]] = {}
        self.last_psi = 0.0
        self.last_per_feature: dict[str, float] = {}
        self.drift_detected = False
        self.last_status = "not_initialized"
        self._load_baseline(feature_names, baseline_csv, baseline_artifact)

    def _load_baseline(
        self,
        feature_names: list[str] | None,
        baseline_csv: Path,
        baseline_artifact: Path,
    ) -> None:
        if baseline_artifact.exists():
            data = json.loads(baseline_artifact.read_text(encoding="utf-8"))
            self.feature_names = data["feature_names"]
            self.baseline_bins = data["bins"]
            self.baseline_expected = data["expected_proportions"]
            self.last_status = "baseline_loaded"
            return

        if not baseline_csv.exists():
            self.last_status = "baseline_missing"
            return

        df = pd.read_csv(baseline_csv)
        meta_cols = {
            "activity_code",
            "subject_id",
            "trial",
            "age_group",
            "fall_event",
            "source_file",
            "window_id",
            "window_index",
            "window_start_ms",
            "window_end_ms",
            "source_start_sample",
            "source_end_sample",
            "sample_rate_hz",
            "samples_per_signal",
        }
        all_features = [c for c in df.columns if c not in meta_cols]
        if feature_names:
            self.feature_names = [f for f in feature_names if f in all_features][:40]
        else:
            self.feature_names = all_features[:40]

        bins: dict[str, list[float]] = {}
        expected: dict[str, list[float]] = {}
        for feat in self.feature_names:
            values = df[feat].dropna().to_numpy(dtype=float)
            if len(values) < N_BINS:
                continue
            quantiles = np.linspace(0, 1, N_BINS + 1)
            edges = np.unique(np.quantile(values, quantiles))
            if len(edges) < 3:
                continue
            bins[feat] = edges.tolist()
            expected[feat] = _histogram_proportions(values, edges).tolist()

        self.baseline_bins = bins
        self.baseline_expected = expected
        self.feature_names = list(bins.keys())
        self._persist_baseline(baseline_artifact)
        self.last_status = "baseline_built"

    def _persist_baseline(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(
                {
                    "feature_names": self.feature_names,
                    "bins": self.baseline_bins,
                    "expected_proportions": self.baseline_expected,
                    "n_bins": N_BINS,
                    "source": str(DEFAULT_BASELINE_CSV),
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

    def set_feature_names(self, feature_names: list[str]) -> None:
        """Align monitored features with the loaded model (call after model reload)."""
        if not feature_names or self.baseline_bins:
            return
        self._load_baseline(feature_names, DEFAULT_BASELINE_CSV, BASELINE_ARTIFACT)

    def record(self, features: dict[str, float]) -> None:
        with self._lock:
            row = {k: float(features[k]) for k in self.feature_names if k in features}
            if row:
                self.recent.append(row)

    def recompute(self) -> dict:
        with self._lock:
            n = len(self.recent)
            if not self.feature_names or not self.baseline_bins:
                self.last_status = "baseline_missing"
                return {
                    "psi": 0.0,
                    "drift_detected": False,
                    "samples": n,
                    "status": self.last_status,
                    "threshold": self.psi_threshold,
                }
            if n < MIN_RECENT_SAMPLES:
                self.last_psi = 0.0
                self.drift_detected = False
                self.last_status = "insufficient_samples"
                return {
                    "psi": 0.0,
                    "drift_detected": False,
                    "samples": n,
                    "status": self.last_status,
                    "threshold": self.psi_threshold,
                    "min_samples": MIN_RECENT_SAMPLES,
                }

            df = pd.DataFrame(list(self.recent))
            per_feature: dict[str, float] = {}
            for feat in self.feature_names:
                if feat not in df.columns:
                    continue
                edges = np.array(self.baseline_bins[feat], dtype=float)
                expected = np.array(self.baseline_expected[feat], dtype=float)
                actual = _histogram_proportions(df[feat].to_numpy(dtype=float), edges)
                per_feature[feat] = _psi(expected, actual)

            if not per_feature:
                self.last_status = "no_overlap"
                return {
                    "psi": 0.0,
                    "drift_detected": False,
                    "samples": n,
                    "status": self.last_status,
                    "threshold": self.psi_threshold,
                }

            mean_psi = float(np.mean(list(per_feature.values())))
            self.last_psi = mean_psi
            self.last_per_feature = {k: round(v, 4) for k, v in per_feature.items()}
            self.drift_detected = mean_psi >= self.psi_threshold
            self.last_status = "ok"

            top = sorted(per_feature.items(), key=lambda x: x[1], reverse=True)[:5]
            return {
                "psi": round(mean_psi, 4),
                "drift_detected": self.drift_detected,
                "samples": n,
                "status": self.last_status,
                "threshold": self.psi_threshold,
                "features_monitored": len(per_feature),
                "top_drift_features": {k: round(v, 4) for k, v in top},
            }

    def snapshot(self) -> dict:
        with self._lock:
            return {
                "psi": round(self.last_psi, 4),
                "drift_detected": self.drift_detected,
                "samples": len(self.recent),
                "status": self.last_status,
                "threshold": self.psi_threshold,
                "features_monitored": len(self.feature_names),
            }

    def seed_samples(self, rows: list[dict[str, float]]) -> None:
        """Test helper — inject feature rows into the recent buffer."""
        with self._lock:
            for row in rows:
                self.recent.append(row)

    def clear_recent(self) -> None:
        with self._lock:
            self.recent.clear()
