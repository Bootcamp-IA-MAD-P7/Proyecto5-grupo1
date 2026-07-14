"""Feature extraction for fall-detection inference.

This module replicates exactly the feature computation from
``ml/build_sisfall_window_features.py`` so that the inference service and the
training pipeline always produce identical feature vectors.

If the training pipeline changes, this file must change in sync.
"""

from __future__ import annotations

import numpy as np

from ml.pipeline.gravity_align import align_window_to_sisfall_frame


# ---------------------------------------------------------------------------
# Helpers (identical to ml/build_sisfall_window_features.py)
# ---------------------------------------------------------------------------

def _safe_skew(values: np.ndarray) -> float:
    std = values.std(ddof=0)
    if std == 0:
        return 0.0
    centered = values - values.mean()
    return float(np.mean((centered / std) ** 3))


def _safe_kurtosis(values: np.ndarray) -> float:
    std = values.std(ddof=0)
    if std == 0:
        return 0.0
    centered = values - values.mean()
    return float(np.mean((centered / std) ** 4) - 3.0)


def _safe_corr(left: np.ndarray, right: np.ndarray) -> float:
    if left.std(ddof=0) == 0 or right.std(ddof=0) == 0:
        return 0.0
    return float(np.corrcoef(left, right)[0, 1])


# ---------------------------------------------------------------------------
# Main extraction entry point
# ---------------------------------------------------------------------------

SIGNAL_ORDER = ["accX", "accY", "accZ", "gyroX", "gyroY", "gyroZ"]


def extract_features(
    accX: list[float],
    accY: list[float],
    accZ: list[float],
    gyroX: list[float],
    gyroY: list[float],
    gyroZ: list[float],
) -> dict[str, float]:
    """Compute the 116-feature vector from raw sensor samples.

    Parameters mirror the ``SensorSamples`` schema in ``api/main.py``.
    Returns a dict with one key per feature name, matching the exact names
    expected by ``model.pkl``.
    """
    accX, accY, accZ, gyroX, gyroY, gyroZ = align_window_to_sisfall_frame(
        accX, accY, accZ, gyroX, gyroY, gyroZ
    )
    window_values = np.array(
        [accX, accY, accZ, gyroX, gyroY, gyroZ], dtype=float
    ).T  # shape (n_samples, 6)

    features: dict[str, float] = {}

    for index, signal in enumerate(SIGNAL_ORDER):
        values = window_values[:, index]
        q25, q75 = np.percentile(values, [25, 75])
        diff_abs = np.abs(np.diff(values))

        features[f"{signal}_mean"] = float(values.mean())
        features[f"{signal}_std"] = float(values.std(ddof=0))
        features[f"{signal}_min"] = float(values.min())
        features[f"{signal}_max"] = float(values.max())
        features[f"{signal}_median"] = float(np.median(values))
        features[f"{signal}_q25"] = float(q25)
        features[f"{signal}_q75"] = float(q75)
        features[f"{signal}_iqr"] = float(q75 - q25)
        features[f"{signal}_rms"] = float(np.sqrt(np.mean(values ** 2)))
        features[f"{signal}_energy"] = float(np.sum(values ** 2) / len(values))
        features[f"{signal}_skew"] = _safe_skew(values)
        features[f"{signal}_kurtosis"] = _safe_kurtosis(values)
        features[f"{signal}_diff_mean_abs"] = float(diff_abs.mean()) if len(diff_abs) else 0.0
        features[f"{signal}_diff_max_abs"] = float(diff_abs.max()) if len(diff_abs) else 0.0

    acc = window_values[:, :3]
    gyro = window_values[:, 3:]
    derived = {
        "acc_magnitude": np.linalg.norm(acc, axis=1),
        "gyro_magnitude": np.linalg.norm(gyro, axis=1),
    }
    for name, values in derived.items():
        q25, q75 = np.percentile(values, [25, 75])
        diff_abs = np.abs(np.diff(values))
        features[f"{name}_mean"] = float(values.mean())
        features[f"{name}_std"] = float(values.std(ddof=0))
        features[f"{name}_min"] = float(values.min())
        features[f"{name}_max"] = float(values.max())
        features[f"{name}_median"] = float(np.median(values))
        features[f"{name}_q25"] = float(q25)
        features[f"{name}_q75"] = float(q75)
        features[f"{name}_iqr"] = float(q75 - q25)
        features[f"{name}_rms"] = float(np.sqrt(np.mean(values ** 2)))
        features[f"{name}_energy"] = float(np.sum(values ** 2) / len(values))
        features[f"{name}_diff_mean_abs"] = float(diff_abs.mean()) if len(diff_abs) else 0.0
        features[f"{name}_diff_max_abs"] = float(diff_abs.max()) if len(diff_abs) else 0.0

    features["acc_sma"] = float(np.sum(np.abs(acc)) / len(window_values))
    features["gyro_sma"] = float(np.sum(np.abs(gyro)) / len(window_values))
    features["acc_xy_corr"] = _safe_corr(acc[:, 0], acc[:, 1])
    features["acc_xz_corr"] = _safe_corr(acc[:, 0], acc[:, 2])
    features["acc_yz_corr"] = _safe_corr(acc[:, 1], acc[:, 2])
    features["gyro_xy_corr"] = _safe_corr(gyro[:, 0], gyro[:, 1])
    features["gyro_xz_corr"] = _safe_corr(gyro[:, 0], gyro[:, 2])
    features["gyro_yz_corr"] = _safe_corr(gyro[:, 1], gyro[:, 2])

    return features
