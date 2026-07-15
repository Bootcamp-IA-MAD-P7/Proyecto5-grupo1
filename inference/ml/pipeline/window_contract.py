"""Shared SL-14 telemetry window contract.

The JSON file at repository root is the source of truth. This module gives
Python training and inference code a typed, importable view without changing
the current model pipeline.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path


def _resolve_contract_path() -> Path:
    candidates = [
        Path(__file__).resolve().parents[3] / "contracts" / "window_contract.json",
        Path("/contracts/window_contract.json"),
    ]
    for path in candidates:
        if path.is_file():
            return path
    return candidates[0]


CONTRACT_PATH = _resolve_contract_path()


@dataclass(frozen=True)
class WindowContract:
    duration_ms: int
    sample_rate_hz: int
    overlap_ratio: float
    hop_ms: int
    samples_per_signal: int
    source_rate_hz: int
    resample_method: str
    acceleration_unit: str
    gyroscope_unit: str
    missing_samples_policy: str
    extra_samples_policy: str
    normalization_policy: str
    required_sample_count: int
    required_sample_rate_hz: int
    allowed_sample_rate_tolerance_hz: int
    reject_nan_or_infinite: bool
    reject_missing_required_signals: bool
    context_required: bool
    required_signal_keys: tuple[str, ...]
    optional_context_keys: tuple[str, ...]


def _require_mapping(raw: dict, key: str) -> dict:
    if key not in raw:
        raise ValueError(f"Invalid window contract: missing '{key}' section")
    value = raw[key]
    if not isinstance(value, dict):
        raise ValueError(f"Invalid window contract: '{key}' must be an object")
    return value


def _require_list(raw: dict, key: str) -> list:
    if key not in raw:
        raise ValueError(f"Invalid window contract: missing '{key}'")
    value = raw[key]
    if not isinstance(value, list):
        raise ValueError(f"Invalid window contract: '{key}' must be a list")
    return value


def _require_string_list(raw: dict, key: str, *, section: str) -> tuple[str, ...]:
    items = _require_list(raw, key)
    values = []
    for index, item in enumerate(items):
        if not isinstance(item, str) or not item:
            raise ValueError(
                f"Invalid window contract: '{section}.{key}[{index}]' "
                "must be a non-empty string"
            )
        values.append(item)
    return tuple(values)


def _require_string(raw: dict, key: str, *, section: str | None = None) -> str:
    path = f"{section}.{key}" if section else key
    if key not in raw:
        raise ValueError(f"Invalid window contract: missing '{path}'")
    value = raw[key]
    if not isinstance(value, str) or not value:
        raise ValueError(
            f"Invalid window contract: '{path}' must be a non-empty string"
        )
    return value


def _require_bool(raw: dict, key: str, *, section: str) -> bool:
    if key not in raw:
        raise ValueError(f"Invalid window contract: missing '{section}.{key}'")
    value = raw[key]
    if not isinstance(value, bool):
        raise ValueError(
            f"Invalid window contract: '{section}.{key}' must be boolean"
        )
    return value


def _require_number(raw: dict, key: str, *, section: str) -> int | float:
    if key not in raw:
        raise ValueError(f"Invalid window contract: missing '{section}.{key}'")
    value = raw[key]
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        raise ValueError(
            f"Invalid window contract: '{section}.{key}' must be numeric"
        )
    return value


def _signal_names(items: list, *, section: str) -> tuple[str, ...]:
    if not items:
        raise ValueError(f"Invalid window contract: '{section}' must not be empty")

    names = []
    for index, item in enumerate(items):
        if not isinstance(item, dict):
            raise ValueError(
                f"Invalid window contract: '{section}[{index}]' must be an object"
            )
        name = item.get("name")
        if not isinstance(name, str) or not name:
            raise ValueError(
                f"Invalid window contract: '{section}[{index}].name' must be a non-empty string"
            )
        unit = item.get("unit")
        if not isinstance(unit, str) or not unit:
            raise ValueError(
                f"Invalid window contract: '{section}[{index}].unit' must be a non-empty string"
            )
        names.append(name)
    return tuple(names)


@lru_cache(maxsize=1)
def load_window_contract() -> WindowContract:
    raw = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ValueError("Invalid window contract: root must be an object")

    _require_string(raw, "schemaVersion")
    _require_string(raw, "source")
    window = _require_mapping(raw, "window")
    preprocessing = _require_mapping(raw, "preprocessing")
    signals = _require_mapping(raw, "signals")
    api = _require_mapping(raw, "api")
    validation = _require_mapping(raw, "validation")
    compatibility = _require_mapping(raw, "compatibility")

    _require_string(api, "telemetryEndpoint", section="api")
    _require_string(api, "inferenceEndpoint", section="api")
    _require_string(api, "timestampFormat", section="api")
    _require_string(api, "windowEndRule", section="api")
    api_sample_keys = _require_string_list(
        api, "samplesObjectKeys", section="api"
    )
    _require_string(compatibility, "training", section="compatibility")
    _require_string(compatibility, "inference", section="compatibility")
    _require_string(compatibility, "flutter", section="compatibility")

    required_signals = _require_list(signals, "required")
    optional_context = _require_list(signals, "optionalContext")

    duration_ms = int(_require_number(window, "durationMs", section="window"))
    sample_rate_hz = int(_require_number(window, "sampleRateHz", section="window"))
    overlap_ratio = float(
        _require_number(window, "overlapRatio", section="window")
    )
    hop_ms = int(_require_number(window, "hopMs", section="window"))
    samples_per_signal = int(
        _require_number(window, "samplesPerSignal", section="window")
    )
    source_rate_hz = int(
        _require_number(preprocessing, "sourceRateHz", section="preprocessing")
    )
    resample_method = _require_string(
        preprocessing, "resampleMethod", section="preprocessing"
    )
    acceleration_unit = _require_string(
        preprocessing, "accelerationUnit", section="preprocessing"
    )
    gyroscope_unit = _require_string(
        preprocessing, "gyroscopeUnit", section="preprocessing"
    )
    _require_string(preprocessing, "gravityHandling", section="preprocessing")
    missing_samples_policy = _require_string(
        preprocessing, "missingSamples", section="preprocessing"
    )
    extra_samples_policy = _require_string(
        preprocessing, "extraSamples", section="preprocessing"
    )
    normalization_policy = _require_string(
        preprocessing, "normalization", section="preprocessing"
    )
    required_sample_count = int(
        _require_number(validation, "requiredSampleCount", section="validation")
    )
    required_sample_rate_hz = int(
        _require_number(validation, "requiredSampleRateHz", section="validation")
    )
    allowed_sample_rate_tolerance_hz = int(
        _require_number(
            validation, "allowedSampleRateToleranceHz", section="validation"
        )
    )
    reject_nan_or_infinite = _require_bool(
        validation, "rejectNaNOrInfinite", section="validation"
    )
    reject_missing_required_signals = _require_bool(
        validation, "rejectMissingRequiredSignals", section="validation"
    )
    context_required = _require_bool(
        validation, "contextRequired", section="validation"
    )

    if duration_ms <= 0:
        raise ValueError("Invalid window contract: 'window.durationMs' must be > 0")
    if sample_rate_hz <= 0:
        raise ValueError("Invalid window contract: 'window.sampleRateHz' must be > 0")
    if not 0 < overlap_ratio < 1:
        raise ValueError(
            "Invalid window contract: 'window.overlapRatio' must be > 0 and < 1"
        )
    if hop_ms <= 0:
        raise ValueError("Invalid window contract: 'window.hopMs' must be > 0")
    if samples_per_signal <= 0:
        raise ValueError(
            "Invalid window contract: 'window.samplesPerSignal' must be > 0"
        )
    if source_rate_hz < sample_rate_hz:
        raise ValueError(
            "Invalid window contract: 'preprocessing.sourceRateHz' must be >= "
            "'window.sampleRateHz'"
        )
    if required_sample_count != samples_per_signal:
        raise ValueError(
            "Invalid window contract: 'validation.requiredSampleCount' must "
            "match 'window.samplesPerSignal'"
        )
    if required_sample_rate_hz != sample_rate_hz:
        raise ValueError(
            "Invalid window contract: 'validation.requiredSampleRateHz' must "
            "match 'window.sampleRateHz'"
        )
    if allowed_sample_rate_tolerance_hz != 0:
        raise ValueError(
            "Invalid window contract: sample-rate tolerance must be 0 for v1"
        )

    expected_samples = duration_ms * sample_rate_hz / 1000
    if samples_per_signal != expected_samples:
        raise ValueError(
            "Invalid window contract: 'window.samplesPerSignal' must equal "
            "window.durationMs * window.sampleRateHz / 1000"
        )

    expected_hop_ms = duration_ms * (1 - overlap_ratio)
    if hop_ms != expected_hop_ms:
        raise ValueError(
            "Invalid window contract: 'window.hopMs' must equal "
            "window.durationMs * (1 - window.overlapRatio)"
        )

    required_signal_keys = _signal_names(
        required_signals, section="signals.required"
    )
    optional_context_keys = _signal_names(
        optional_context, section="signals.optionalContext"
    )
    if tuple(api_sample_keys) != required_signal_keys:
        raise ValueError(
            "Invalid window contract: 'api.samplesObjectKeys' must match "
            "'signals.required' names"
        )

    return WindowContract(
        duration_ms=duration_ms,
        sample_rate_hz=sample_rate_hz,
        overlap_ratio=overlap_ratio,
        hop_ms=hop_ms,
        samples_per_signal=samples_per_signal,
        source_rate_hz=source_rate_hz,
        resample_method=resample_method,
        acceleration_unit=acceleration_unit,
        gyroscope_unit=gyroscope_unit,
        missing_samples_policy=missing_samples_policy,
        extra_samples_policy=extra_samples_policy,
        normalization_policy=normalization_policy,
        required_sample_count=required_sample_count,
        required_sample_rate_hz=required_sample_rate_hz,
        allowed_sample_rate_tolerance_hz=allowed_sample_rate_tolerance_hz,
        reject_nan_or_infinite=reject_nan_or_infinite,
        reject_missing_required_signals=reject_missing_required_signals,
        context_required=context_required,
        required_signal_keys=required_signal_keys,
        optional_context_keys=optional_context_keys,
    )


WINDOW_CONTRACT = load_window_contract()
