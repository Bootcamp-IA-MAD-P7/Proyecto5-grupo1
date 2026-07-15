"""Tests for T4.2 CNN 1D training pipeline."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from ml.training.compare_cnn1d import _subject_split, find_best_threshold_from_probs
from ml.training.train_model import RANDOM_STATE, group_split

ARTIFACT = Path("ml/artifacts/cnn1d_comparison.json")


def test_subject_split_has_no_leakage():
    rng = np.random.default_rng(RANDOM_STATE)
    n = 200
    groups = np.array([f"S{i // 5:02d}" for i in range(n)])
    y = rng.integers(0, 2, size=n)

    train_idx, val_idx, test_idx = _subject_split(y, groups)
    train_subjects = set(groups[train_idx])
    val_subjects = set(groups[val_idx])
    test_subjects = set(groups[test_idx])

    assert not train_subjects & val_subjects
    assert not train_subjects & test_subjects
    assert not val_subjects & test_subjects
    assert len(train_idx) + len(val_idx) + len(test_idx) == n


def test_group_split_matches_train_model():
    index = pd.DataFrame({"idx": np.arange(60)})
    y = pd.Series([0, 1] * 30)
    groups = pd.Series([f"S{i // 6:02d}" for i in range(60)])

    train_idx, temp_idx = group_split(index, y, groups, 0.3, RANDOM_STATE)
    train_subjects = set(groups.iloc[train_idx])
    temp_subjects = set(groups.iloc[temp_idx])
    assert not train_subjects & temp_subjects


def test_find_best_threshold_from_probs():
    probs = np.array([0.1, 0.2, 0.8, 0.9])
    y = np.array([0, 0, 1, 1])
    threshold = find_best_threshold_from_probs(probs, y)
    assert 0.05 <= threshold <= 0.95


@pytest.mark.skipif(not ARTIFACT.exists(), reason="Run compare_cnn1d.py first")
def test_cnn1d_comparison_artifact_schema():
    report = json.loads(ARTIFACT.read_text())
    assert report["task"] == "T4.2 / ML-15"
    assert report["model_type"] == "CNN1D"
    cnn = report["cnn1d"]
    assert cnn["overfitting_gap_pp"] < 5.0
    assert cnn["overfitting_ok"] is True
    assert report["n_subjects"] >= 30
    assert Path(report["model_path"]).exists()


def test_load_raw_windows_shape():
    from ml.training.raw_windows import load_raw_windows

    root = Path("data/raw/sisfall")
    if not root.exists():
        pytest.skip("SisFall raw data not available")

    X, y, groups = load_raw_windows(root)
    assert X.shape[1:] == (125, 6)
    assert len(X) == len(y) == len(groups)
    assert set(np.unique(y)).issubset({0, 1})
