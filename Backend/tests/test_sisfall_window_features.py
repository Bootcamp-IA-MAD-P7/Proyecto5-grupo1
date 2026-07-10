import numpy as np
import pandas as pd

from ml.build_sisfall_window_features import (
    _window_starts_seconds,
    build_window_features,
    extract_contract_window,
    statistical_features,
)
from ml.window_contract import WINDOW_CONTRACT


def synthetic_trial(seconds=3.75):
    n_samples = int(seconds * WINDOW_CONTRACT.source_rate_hz)
    t = np.arange(n_samples) / WINDOW_CONTRACT.source_rate_hz
    return pd.DataFrame(
        {
            "accX": np.sin(t),
            "accY": np.cos(t),
            "accZ": np.full_like(t, 9.80665),
            "gyroX": t,
            "gyroY": t * 2,
            "gyroZ": t * 3,
        }
    )


def test_window_starts_follow_contract_hop_ms_with_fractional_sample_hop():
    starts = _window_starts_seconds(len(synthetic_trial()))

    assert starts.tolist() == [0.0, 1.25]


def test_extract_contract_window_has_exact_required_signals_and_sample_count():
    window = extract_contract_window(synthetic_trial(), start_seconds=1.25)

    assert tuple(window.columns) == WINDOW_CONTRACT.required_signal_keys
    assert len(window) == WINDOW_CONTRACT.samples_per_signal
    assert np.isfinite(window.to_numpy()).all()
    assert window["gyroX"].iloc[0] == 1.25


def test_statistical_features_are_finite_and_include_required_signal_prefixes():
    features = statistical_features(extract_contract_window(synthetic_trial(), 0.0))

    assert "accX_mean" in features
    assert "gyroZ_diff_max_abs" in features
    assert "acc_magnitude_max" in features
    assert "gyro_yz_corr" in features
    assert all(np.isfinite(value) for value in features.values())


def test_build_window_features_writes_deterministic_metadata(tmp_path):
    raw_root = tmp_path / "raw"
    subject_dir = raw_root / "SA01"
    subject_dir.mkdir(parents=True)
    raw_file = subject_dir / "F01_SA01_R01.txt"
    rows = []
    for i in range(int(3.75 * WINDOW_CONTRACT.source_rate_hz)):
        rows.append(f"{i},{i+1},{i+2},{i+3},{i+4},{i+5},{i+6},{i+7},{i+8};")
    raw_file.write_text("\n".join(rows), encoding="latin-1")

    df, manifest = build_window_features(raw_root)

    assert len(df) == 2
    assert set(df["window_id"]) == {"F01_SA01_R01_W0000", "F01_SA01_R01_W0001"}
    assert df["fall_event"].tolist() == [1, 1]
    assert df["sample_rate_hz"].eq(WINDOW_CONTRACT.sample_rate_hz).all()
    assert manifest["windows"] == 2
    assert manifest["feature_count"] > 0
