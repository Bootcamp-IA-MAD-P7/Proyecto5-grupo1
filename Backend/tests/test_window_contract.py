from ml.window_contract import WINDOW_CONTRACT


def test_window_contract_values_match_sl14():
    assert WINDOW_CONTRACT.duration_ms == 2500
    assert WINDOW_CONTRACT.sample_rate_hz == 50
    assert WINDOW_CONTRACT.overlap_ratio == 0.5
    assert WINDOW_CONTRACT.hop_ms == 1250
    assert WINDOW_CONTRACT.samples_per_signal == 125
    assert WINDOW_CONTRACT.required_sample_count == 125
    assert WINDOW_CONTRACT.required_sample_rate_hz == 50
    assert WINDOW_CONTRACT.allowed_sample_rate_tolerance_hz == 0


def test_window_contract_signal_format_matches_spec():
    assert WINDOW_CONTRACT.required_signal_keys == (
        "accX",
        "accY",
        "accZ",
        "gyroX",
        "gyroY",
        "gyroZ",
    )
    assert WINDOW_CONTRACT.optional_context_keys == (
        "heartRate",
        "roomTemp",
        "roomLight",
    )


def test_window_contract_preprocessing_rules_are_explicit():
    assert WINDOW_CONTRACT.source_rate_hz == 200
    assert WINDOW_CONTRACT.resample_method == "linear_interpolation_to_50hz"
    assert WINDOW_CONTRACT.acceleration_unit == "m/s^2"
    assert WINDOW_CONTRACT.gyroscope_unit == "deg/s"
    assert WINDOW_CONTRACT.reject_nan_or_infinite is True
    assert WINDOW_CONTRACT.reject_missing_required_signals is True
    assert WINDOW_CONTRACT.context_required is False
    assert "125_samples" in WINDOW_CONTRACT.missing_samples_policy
    assert "125_samples" in WINDOW_CONTRACT.extra_samples_policy
    assert "physical units" in WINDOW_CONTRACT.normalization_policy
