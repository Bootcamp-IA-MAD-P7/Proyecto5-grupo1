from ml.window_contract import WINDOW_CONTRACT


def test_window_contract_values_match_sl14():
    assert WINDOW_CONTRACT.duration_ms == 2500
    assert WINDOW_CONTRACT.sample_rate_hz == 50
    assert WINDOW_CONTRACT.overlap_ratio == 0.5
    assert WINDOW_CONTRACT.hop_ms == 1250
    assert WINDOW_CONTRACT.samples_per_signal == 125


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
