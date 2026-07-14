"""Tests for T4.4 retrain pipeline (ML-19 / RF-33)."""

from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import patch

import pandas as pd
import pytest
from fastapi.testclient import TestClient

from api.main import app
from ml.training.retrain_feedback import (
    FEEDBACK_DIR,
    _label_to_fall_event,
    _parse_samples_json,
    load_feedback_records,
    run_retrain,
)

client = TestClient(app)


def test_label_to_fall_event_mapping():
    assert _label_to_fall_event("TRUE_FALL") == 1
    assert _label_to_fall_event("FALSE_ALARM") == 0
    assert _label_to_fall_event("unknown") is None


def test_parse_samples_json_requires_125_samples():
    samples = {sig: [0.1] * 125 for sig in ("accX", "accY", "accZ", "gyroX", "gyroY", "gyroZ")}
    parsed = _parse_samples_json(json.dumps(samples))
    assert parsed is not None
    assert len(parsed["accX"]) == 125

    short = {sig: [0.1] * 10 for sig in samples}
    assert _parse_samples_json(json.dumps(short)) is None


def test_load_feedback_records_reads_sample_csv():
    if not (FEEDBACK_DIR / "labeled_feedback_sample.csv").exists():
        pytest.skip("Feedback sample CSV not available")

    df, meta = load_feedback_records()
    assert meta["total_records"] >= 2
    assert meta["true_fall"] >= 1
    assert meta["false_alarm"] >= 1
    assert "labeled_feedback_sample.csv" in meta["files"]
    # Sample CSV has no samples_json — no augmented rows
    assert df is None or df.empty or meta["augmented_windows"] == 0


def test_train_endpoint_contract_with_mock():
    mock_result = {
        "version": "xgboost-retrain-test",
        "algorithm": "XGBoost",
        "recall": 0.91,
        "precision": 0.75,
        "f1": 0.82,
        "overfitting": 0.02,
        "artifact_uri": "ml/models/retrain-test.pkl",
        "metrics": {
            "recall": 0.91,
            "precision": 0.75,
            "f1": 0.82,
            "overfitting": 0.02,
            "current_recall": 0.89,
            "previous_version": "xgboost-v1.1.0-mobile-aligned",
        },
    }
    with patch("api.main.run_retrain", return_value=mock_result):
        response = client.post("/train")
    assert response.status_code == 200
    data = response.json()
    assert data["version"] == "xgboost-retrain-test"
    assert data["recall"] == pytest.approx(0.91)
    assert data["overfitting"] == pytest.approx(0.02)
    assert data["artifact_uri"] == "ml/models/retrain-test.pkl"
    assert data["metrics"]["current_recall"] == pytest.approx(0.89)


def test_run_retrain_produces_measurable_metrics(tmp_path):
    features = Path("data/processed/sisfall/sisfall_windows_features.csv.gz")
    if not features.exists():
        pytest.skip("SisFall features not available")

    registry_backup = Path("ml/registry/registry.json").read_text(encoding="utf-8")
    models_before = set(Path("ml/models").glob("retrain-*.pkl"))

    try:
        result = run_retrain(skip_feature_build=True)
    finally:
        Path("ml/registry/registry.json").write_text(registry_backup, encoding="utf-8")
        for artifact in Path("ml/models").glob("retrain-*.pkl"):
            if artifact not in models_before:
                artifact.unlink(missing_ok=True)

    assert result["version"].startswith("xgboost-retrain-")
    assert 0.0 <= result["recall"] <= 1.0
    assert 0.0 <= result["precision"] <= 1.0
    assert 0.0 <= result["f1"] <= 1.0
    assert result["overfitting"] >= 0.0
    assert Path(result["artifact_uri"]).suffix == ".pkl"
    assert Path(result["artifact_uri"]).exists()

    metrics_path = Path("ml/artifacts/retrain_metrics.json")
    assert metrics_path.exists()
    doc = json.loads(metrics_path.read_text(encoding="utf-8"))
    assert doc["task"] == "T4.4"
    assert doc["test"]["recall_fall"] == pytest.approx(result["recall"], rel=1e-4)
