"""Tests for ADL replay gate — T2c.5 (0 alertas en actividad normal)."""

from __future__ import annotations

from pathlib import Path

import pytest

from ml.evaluation.adl_replay import ADLReplayResult, run_adl_replay

MODEL_PATH = Path(__file__).resolve().parents[1] / "ml" / "models" / "model.pkl"


@pytest.fixture(scope="module")
def replay_result() -> ADLReplayResult:
    if not MODEL_PATH.exists():
        pytest.skip("model.pkl not built yet")
    return run_adl_replay(model_path=MODEL_PATH)


def test_adl_replay_has_windows(replay_result: ADLReplayResult):
    assert replay_result.total_windows >= 3
    assert replay_result.adl_false_positives == 0


def test_mobile_adl_rest_not_flagged_as_fall(replay_result: ADLReplayResult):
    mobile = next(
        (r for r in replay_result.windows if "mobile_adl" in r.fixture_name),
        None,
    )
    assert mobile is not None
    assert mobile.fall_detected is False


def test_sisfall_adl_walk_not_flagged_as_fall(replay_result: ADLReplayResult):
    adl = next(
        (r for r in replay_result.windows if "sisfall_adl" in r.fixture_name),
        None,
    )
    assert adl is not None
    assert adl.fall_detected is False
