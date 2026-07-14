"""Tests for mobile ↔ SisFall parity diagnosis — T2c.4."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from ml.evaluation.parity_diagnosis import (
    FIXTURES_DIR,
    REQUIRED_SAMPLES,
    diagnose_fixture,
    features_from_samples,
    run_diagnosis,
    training_features_from_samples,
    validate_samples,
)
from ml.pipeline.window_contract import WINDOW_CONTRACT

SIGNALS = WINDOW_CONTRACT.required_signal_keys


def _sample_payload() -> dict[str, list[float]]:
    return {sig: [float(i) for i in range(REQUIRED_SAMPLES)] for sig in SIGNALS}


def test_validate_samples_requires_125_finite_values():
    ok_count, ok_finite = validate_samples(_sample_payload())
    assert ok_count is True
    assert ok_finite is True

    bad = _sample_payload()
    bad["accX"] = bad["accX"][:-1]
    bad_count, _ = validate_samples(bad)
    assert bad_count is False


def test_inference_matches_training_pipeline():
    samples = _sample_payload()
    for sig in SIGNALS:
        if sig == "accZ":
            samples[sig] = [9.80665] * REQUIRED_SAMPLES
    inference = features_from_samples(samples)
    training = training_features_from_samples(samples)
    assert len(inference) == 116
    for key in inference:
        assert abs(inference[key] - training[key]) < 1e-6


@pytest.fixture(scope="module")
def fixtures_dir() -> Path:
    if not FIXTURES_DIR.exists() or not list(FIXTURES_DIR.glob("*.json")):
        from scripts.generate_mobile_fixtures import main as generate

        generate()
    return FIXTURES_DIR


def test_all_fixtures_pass_contract_checks(fixtures_dir: Path):
    for path in fixtures_dir.glob("*.json"):
        data = json.loads(path.read_text(encoding="utf-8"))
        diag = diagnose_fixture(data)
        assert diag.sample_count_ok, path.name
        assert diag.finite_ok, path.name
        assert diag.training_pipeline_match, path.name
        assert diag.feature_count == 116


def test_diagnosis_detects_gravity_axis_shift(fixtures_dir: Path):
    result = run_diagnosis(fixtures_dir)
    assert "mobile_adl_vs_sisfall_adl" in result["distribution_shift"]
    mobile = result["fixtures"]["mobile_adl_rest_portrait"]
    sisfall = result["fixtures"]["sisfall_adl_walk"]
    assert abs(mobile["acc_y_mean"] - sisfall["acc_y_mean"]) > 5.0
    assert any("GRAVITY_AXIS" in c for c in result["root_causes"])
    assert result["threshold_change_allowed"] is False


def test_diagnosis_report_root_causes_not_empty(fixtures_dir: Path):
    result = run_diagnosis(fixtures_dir)
    assert len(result["root_causes"]) >= 1
    assert result["feature_order_ok"] is True
