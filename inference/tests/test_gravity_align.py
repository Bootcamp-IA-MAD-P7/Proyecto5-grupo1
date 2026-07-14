"""Tests for gravity alignment preprocessing — T2c.5 / ADR-11."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pytest

from api.inference.features import extract_features
from ml.evaluation.parity_diagnosis import FIXTURES_DIR, features_from_samples
from ml.pipeline.gravity_align import (
    SISFALL_GRAVITY_REF,
    align_window_to_sisfall_frame,
    align_window_values,
)


@pytest.fixture(scope="module")
def fixtures_dir() -> Path:
    if not FIXTURES_DIR.exists() or not list(FIXTURES_DIR.glob("*.json")):
        from scripts.generate_mobile_fixtures import main as generate

        generate()
    return FIXTURES_DIR


def test_align_maps_portrait_gravity_to_sisfall_y_axis():
    n = 125
    accX = [0.1] * n
    accY = [9.8] * n
    accZ = [0.2] * n
    gyro = [0.0] * n

    aligned = align_window_to_sisfall_frame(accX, accY, accZ, gyro, gyro, gyro)
    ay = np.mean(aligned[1])
    ax = np.mean(aligned[0])
    az = np.mean(aligned[2])

    assert ay == pytest.approx(SISFALL_GRAVITY_REF[1], rel=0.05, abs=0.5)
    assert abs(ax) < 1.0
    assert abs(az) < 1.0


def test_align_reduces_mobile_adl_feature_shift_vs_sisfall(fixtures_dir: Path):
    mobile = json.loads((fixtures_dir / "mobile_adl_rest_portrait.json").read_text())
    sisfall = json.loads((fixtures_dir / "sisfall_adl_walk.json").read_text())

    mobile_feats = features_from_samples(mobile["samples"])
    sisfall_feats = features_from_samples(sisfall["samples"])

    delta_y = abs(mobile_feats["accY_mean"] - sisfall_feats["accY_mean"])
    assert delta_y < 2.0, f"accY_mean still misaligned: {delta_y:.2f}"


def test_align_window_values_preserves_sample_count():
    n = 125
    window = np.column_stack(
        [
            np.full(n, 0.1),
            np.full(n, 9.8),
            np.full(n, 0.2),
            np.zeros(n),
            np.zeros(n),
            np.zeros(n),
        ]
    )
    signals = ["accX", "accY", "accZ", "gyroX", "gyroY", "gyroZ"]
    aligned = align_window_values(window, signals)
    assert aligned.shape == window.shape


def test_extract_features_applies_alignment():
    n = 125
    raw_feats = extract_features(
        [0.1] * n,
        [9.8] * n,
        [0.2] * n,
        [0.0] * n,
        [0.0] * n,
        [0.0] * n,
    )
    assert raw_feats["accY_mean"] == pytest.approx(SISFALL_GRAVITY_REF[1], rel=0.05, abs=0.5)
