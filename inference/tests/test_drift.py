"""Tests for feature drift monitoring (T4.7 / ML-18)."""

from __future__ import annotations

import numpy as np
import pytest
from fastapi.testclient import TestClient

from api.inference.drift import DriftMonitor, _psi
from api.main import app, _drift_monitor

client = TestClient(app)


def test_psi_identical_distributions_near_zero():
    expected = np.array([0.2, 0.3, 0.5])
    actual = np.array([0.2, 0.3, 0.5])
    assert _psi(expected, actual) < 0.01


def test_psi_shifted_distributions_is_high():
    expected = np.array([0.9, 0.05, 0.05])
    actual = np.array([0.05, 0.05, 0.9])
    assert _psi(expected, actual) > 0.2


def test_drift_monitor_detects_shift():
    import pandas as pd
    from pathlib import Path

    monitor = DriftMonitor()
    if not monitor.feature_names:
        pytest.skip("No drift baseline available")

    csv = Path("data/processed/sisfall/sisfall_windows_features.csv.gz")
    if not csv.exists():
        pytest.skip("SisFall feature CSV not available")

    feat = monitor.feature_names[0]
    df = pd.read_csv(csv, usecols=[feat])
    stable_vals = df[feat].sample(50, random_state=42)

    monitor.clear_recent()
    monitor.seed_samples([{feat: float(v)} for v in stable_vals])
    stable = monitor.recompute()

    monitor.clear_recent()
    shifted_vals = stable_vals + stable_vals.std() * 50
    monitor.seed_samples([{feat: float(v)} for v in shifted_vals])
    shifted = monitor.recompute()

    assert shifted["psi"] > stable["psi"]
    assert shifted["psi"] >= 0.2
    assert shifted.get("drift_detected") is True
    assert shifted["samples"] == 50


def test_drift_endpoints():
    response = client.get("/drift")
    assert response.status_code == 200
    data = response.json()
    assert "psi" in data
    assert "drift_detected" in data
    assert "threshold" in data

    recompute = client.post("/drift/recompute")
    assert recompute.status_code == 200
    body = recompute.json()
    assert "psi" in body
    assert "status" in body


def test_metrics_expose_drift_gauges():
    client.post("/drift/recompute")
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "feature_drift_psi" in response.text
    assert "feature_drift_detected" in response.text
    assert "feature_drift_samples" in response.text


def test_predict_records_drift_sample():
    if _drift_monitor.feature_names:
        before = len(_drift_monitor.recent)
        payload = {
            "windowId": "drift-test",
            "monitoredId": "m1",
            "sampleRateHz": 50,
            "samples": {
                sig: [0.1 if sig.startswith("acc") else 1.0] * 125
                for sig in ["accX", "accY", "accZ", "gyroX", "gyroY", "gyroZ"]
            },
        }
        client.post("/predict", json=payload)
        assert len(_drift_monitor.recent) >= before
