"""Gravity alignment to SisFall reference frame — T2c.5 / ADR-11.

Rotates accelerometer and gyroscope samples so the mean gravity vector in each
window aligns with the SisFall belt IMU reference (0, -g, 0). This makes
mobile portrait ADL windows feature-compatible with training data without
changing the 116-feature contract.
"""

from __future__ import annotations

import numpy as np

STANDARD_GRAVITY = 9.80665
SISFALL_GRAVITY_REF = np.array([0.0, -STANDARD_GRAVITY, 0.0], dtype=float)


def _rotation_matrix(from_vec: np.ndarray, to_vec: np.ndarray) -> np.ndarray:
    """Return 3×3 rotation mapping ``from_vec`` onto ``to_vec`` (same magnitude)."""
    fn = np.linalg.norm(from_vec)
    tn = np.linalg.norm(to_vec)
    if fn < 1e-8 or tn < 1e-8:
        return np.eye(3)

    a = from_vec / fn
    b = to_vec / tn
    v = np.cross(a, b)
    c = float(np.dot(a, b))

    if c > 0.999999:
        return np.eye(3)
    if c < -0.999999:
        axis = np.array([1.0, 0.0, 0.0])
        if abs(a[0]) > 0.9:
            axis = np.array([0.0, 0.0, 1.0])
        v = np.cross(a, axis)
        c = -1.0

    s = np.linalg.norm(v)
    if s < 1e-8:
        return np.eye(3)

    vx = np.array(
        [
            [0.0, -v[2], v[1]],
            [v[2], 0.0, -v[0]],
            [-v[1], v[0], 0.0],
        ]
    )
    return np.eye(3) + vx + vx @ vx * ((1.0 - c) / (s**2))


def align_window_to_sisfall_frame(
    accX: list[float],
    accY: list[float],
    accZ: list[float],
    gyroX: list[float],
    gyroY: list[float],
    gyroZ: list[float],
) -> tuple[list[float], list[float], list[float], list[float], list[float], list[float]]:
    """Rotate acc/gyro lists into the SisFall reference frame."""
    acc = np.column_stack([accX, accY, accZ]).astype(float)
    gyro = np.column_stack([gyroX, gyroY, gyroZ]).astype(float)

    gravity = acc.mean(axis=0)
    g_norm = np.linalg.norm(gravity)
    if g_norm < 1e-6:
        return accX, accY, accZ, gyroX, gyroY, gyroZ

    target = SISFALL_GRAVITY_REF / np.linalg.norm(SISFALL_GRAVITY_REF) * g_norm
    rotation = _rotation_matrix(gravity, target)

    acc_aligned = (rotation @ acc.T).T
    gyro_aligned = (rotation @ gyro.T).T

    return (
        acc_aligned[:, 0].tolist(),
        acc_aligned[:, 1].tolist(),
        acc_aligned[:, 2].tolist(),
        gyro_aligned[:, 0].tolist(),
        gyro_aligned[:, 1].tolist(),
        gyro_aligned[:, 2].tolist(),
    )


def align_window_values(window_values: np.ndarray, signals: list[str]) -> np.ndarray:
    """Apply gravity alignment to a (n_samples, n_signals) window matrix."""
    signal_index = {signal: index for index, signal in enumerate(signals)}
    accX = window_values[:, signal_index["accX"]].tolist()
    accY = window_values[:, signal_index["accY"]].tolist()
    accZ = window_values[:, signal_index["accZ"]].tolist()
    gyroX = window_values[:, signal_index["gyroX"]].tolist()
    gyroY = window_values[:, signal_index["gyroY"]].tolist()
    gyroZ = window_values[:, signal_index["gyroZ"]].tolist()

    aligned = align_window_to_sisfall_frame(accX, accY, accZ, gyroX, gyroY, gyroZ)
    out = window_values.copy()
    out[:, signal_index["accX"]] = aligned[0]
    out[:, signal_index["accY"]] = aligned[1]
    out[:, signal_index["accZ"]] = aligned[2]
    out[:, signal_index["gyroX"]] = aligned[3]
    out[:, signal_index["gyroY"]] = aligned[4]
    out[:, signal_index["gyroZ"]] = aligned[5]
    return out
